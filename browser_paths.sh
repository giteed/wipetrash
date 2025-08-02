#!/usr/bin/env bash
# browser_paths – построение browser_cache.conf (scan only)
# 1.5.22 — 2024-05-21 (scan only with Firefox profiles.ini fix and help)
set -euo pipefail
IFS=$'\n\t'

# ── Совместимость: проверка версии Bash для ${parameter,,}
if (( BASH_VERSINFO[0] < 4 )); then
  echo "Error: This script requires Bash 4.0 or higher." >&2
  exit 1
fi

# ── Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Аргументы
FORCE=0
DEBUG=0

show_help() {
cat << EOF
Usage: ${0##*/} [OPTIONS]

Scan browser profiles and generate a configuration file for cache cleaning.

OPTIONS:
    -h, --help     Show this help message and exit.
    --force        Overwrite the existing browser_cache.conf file.
    --debug        Enable debug output.

DESCRIPTION:
    This script scans common locations for installed browsers (Chrome, Firefox,
    Opera, etc.) and their user profiles. It identifies cache directories and
    other data files, then writes their paths to a configuration file named
    'browser_cache.conf'. This file is intended for use by a separate cleaning script.

    The script only scans and generates the config. It does not delete or move any files.

EXAMPLES:
    Scan and create config (if it doesn't exist):
        ${0##*/}

    Force re-scan and overwrite config:
        ${0##*/} --force

    Scan with verbose debug output:
        ${0##*/} --debug

EOF
}

for arg in "$@"; do
  case $arg in
    -h|--help)
      show_help
      exit 0
      ;;
    --force)
      FORCE=1
      ;;
    --debug)
      DEBUG=1
      ;;
    *)
      echo -e "${RED}Unknown flag: $arg${NC}" >&2
      echo "See '${0##*/} --help' for more information." >&2
      exit 1
      ;;
  esac
done

dbg() {
  ((DEBUG)) && echo -e "${BLUE}[debug]${NC} $*" >&2
}

# ── Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/browser_cache.conf"
BACKUP="$CONF.$(date +%s).bak"

# ── Проверка на sudo
if [[ $EUID -eq 0 ]]; then
  echo -e "${RED}Error: Do not run with sudo${NC}" >&2
  exit 1
fi

# ── Подготовка конфига
if [[ -f "$CONF" && $FORCE -eq 0 ]]; then
  echo -e "${GREEN}Config file:${NC} $CONF"
else
  if [[ -f "$CONF" ]]; then
    mv "$CONF" "$BACKUP"
    echo "Old config → $BACKUP"
  fi
  dbg "Creating new config file"
  {
    echo "# browser_cache.conf — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# path|label|mode (auto|ask|skip)"
    echo
  } >"$CONF"
fi

# Функция обработки Chromium-подобных браузеров
process_chromium_like() {
  local name="$1"
  local root="$2"

  dbg "process_chromium_like: $name @ $root"
  local profs=()

  # Сначала добавляем Default, если он есть
  if [[ -d "$root/Default" ]]; then
    profs+=("$root/Default")
  fi

  # Затем ищем другие профили
  while IFS= read -r -d '' profile; do
    # Исключаем Default, так как он уже добавлен
    if [[ "${profile##*/}" != "Default" ]]; then
        profs+=("$profile")
    fi
  done < <(find "$root" -maxdepth 1 -type d -name 'Profile *' -print0 2>/dev/null || true)

  # Если профилей не найдено, используем корневую папку
  if (( ${#profs[@]} == 0 )); then
    profs=("$root")
  fi

  echo -e "${GREEN}✓ $name – ${#profs[@]} profile(s)${NC}"

  for p in "${profs[@]}"; do
    dbg "  profile: $p"
    local hdr="# $name (${p##*/})"
    # Проверяем, существует ли уже такой заголовок
    if ! grep -Fqx "$hdr" "$CONF"; then
        echo -e "\n$hdr" >>"$CONF"
        dbg "    + header"
    fi

    # global caches for Default profile
    if [[ "${p##*/}" == "Default" ]]; then
      for sub in GraphiteDawnCache GrShaderCache ShaderCache; do
        if [[ -d "$root/$sub" ]]; then
            echo "$root/$sub|$sub|auto" >>"$CONF"
            dbg "    + global $sub"
        fi
      done
    fi

    # profile items
    [[ -d "$p/Cache" ]]           && { echo "$p/Cache|Cache|auto" >>"$CONF"; dbg "    + Cache"; }
    [[ -d "$p/GPUCache" ]]        && { echo "$p/GPUCache|GPUCache|auto" >>"$CONF"; dbg "    + GPUCache"; }
    [[ -d "$p/DawnWebGPUCache" ]] && { echo "$p/DawnWebGPUCache|DawnWebGPU|auto" >>"$CONF"; dbg "    + DawnWebGPUCache"; }
    # Chromium-like Cookies
    [[ -f "$p/Cookies" ]]         && { echo "$p/Cookies|Cookies|ask" >>"$CONF"; dbg "    + Cookies (Chromium)"; }
    [[ -d "$p/Crash Reports" ]]   && { echo "$p/Crash Reports|CrashReports|auto" >>"$CONF"; dbg "    + Crash Reports"; }
  done
  dbg "process_chromium_like: done for $name"
}

# Функция обработки Firefox (читает profiles.ini)
process_firefox() {
  local name="$1"
  local root="$2" # Это путь к папке, содержащей profiles.ini

  dbg "process_firefox: $name @ $root"
  
  # Проверяем, есть ли profiles.ini
  if [[ ! -f "$root/profiles.ini" ]]; then
      dbg "  - profiles.ini not found, skipping"
      return
  fi

  # Читаем profiles.ini и ищем профили
  local profs=()
  # Используем временный файл для надежности
  local temp_ini
  temp_ini=$(mktemp)
  # Убираем BOM, если есть, и нормализуем окончания строк
  tail -c +4 "$root/profiles.ini" | sed 's/\r$//' > "$temp_ini" 2>/dev/null || cp "$root/profiles.ini" "$temp_ini"
  
  while IFS='=' read -r key value; do
    # Ищем строки вида Path=... (игнорируем Install и другие)
    if [[ "$key" == Path ]]; then
        # profiles.ini может содержать относительные пути
        local full_profile_path="$root/$value"
        if [[ -d "$full_profile_path" ]]; then
            profs+=("$full_profile_path")
            dbg "    + found profile path: $full_profile_path"
        else
            dbg "    - profile path from ini does not exist: $full_profile_path"
        fi
    fi
  done < <(grep -E '^Path=' "$temp_ini" 2>/dev/null || true)
  
  rm -f "$temp_ini"

  # Если профилей не найдено по profiles.ini, используем fallback-логику
  if (( ${#profs[@]} == 0 )); then
    dbg "  - No profiles found in profiles.ini, using fallback search"
    # Ищем любые подкаталоги, которые могут быть профилями
    while IFS= read -r -d '' profile; do
        # Пропускаем скрытые каталоги
        if [[ "$(basename "$profile")" != .* ]]; then
            profs+=("$profile")
            dbg "    + found potential profile (fallback): $profile"
        fi
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0 2>/dev/null || true)

    # Если и так не нашли, используем саму root
    if (( ${#profs[@]} == 0 )); then
        profs=("$root")
        dbg "    + using root as fallback profile: $root"
    fi
  fi

  echo -e "${GREEN}✓ $name – ${#profs[@]} profile(s)${NC}"

  for p in "${profs[@]}"; do
    dbg "  profile: $p"
    local hdr="# $name (${p##*/})"
    # Проверяем, существует ли уже такой заголовок
    if ! grep -Fqx "$hdr" "$CONF"; then
        echo -e "\n$hdr" >>"$CONF"
        dbg "    + header"
    fi

    # Firefox items
    [[ -f "$p/cookies.sqlite" ]]     && { echo "$p/cookies.sqlite|Cookies|ask" >>"$CONF"; dbg "    + Cookies (Firefox)"; }
    [[ -d "$p/storage/default" ]]    && { echo "$p/storage/default|Storage|auto" >>"$CONF"; dbg "    + Storage (Firefox)"; }
    [[ -d "$p/cache2/entries" ]]     && { echo "$p/cache2/entries|Cache2|auto" >>"$CONF"; dbg "    + Cache2 (Firefox)"; }
    [[ -d "$p/thumbnails" ]]         && { echo "$p/thumbnails|Thumbnails|auto" >>"$CONF"; dbg "    + Thumbnails (Firefox)"; }
    # Добавлено с осторожностью, так как имя файла может отличаться
    # [[ -f "$p/SiteSecurityServiceState.txt" ]] && { echo "$p/SiteSecurityServiceState.txt|HSTS|auto" >>"$CONF"; dbg "    + HSTS (Firefox)"; }
  done
  dbg "process_firefox: done for $name"
}


# 1) локальные ~/.config
declare -A CHROMIUM_LIKE_MAP=(
  [google-chrome]="Chrome"
  [yandex-browser]="Yandex"
  [chromium]="Chromium"
  [microsoft-edge]="Edge"
  [opera]="Opera"
  [vivaldi]="Vivaldi"
  ["BraveSoftware/Brave-Browser"]="Brave"
)

dbg "Scanning ~/.config for Chromium-like browsers"
for id in "${!CHROMIUM_LIKE_MAP[@]}"; do
  root="$HOME/.config/$id"
  dbg " checking $root"
  if [[ -f "$root/Local State" ]]; then
    process_chromium_like "${CHROMIUM_LIKE_MAP[$id]}" "$root"
  fi
done
dbg "Finished scanning ~/.config for Chromium-like browsers"

# 2) snap-версии
dbg "Scanning snap"
for pkg in chromium google-chrome firefox opera brave; do
  # Chromium-like browsers in snap
  root1="$HOME/snap/$pkg/current/.config/$pkg"
  dbg " checking snap/current $root1"
  if [[ -f "$root1/Local State" ]]; then
    process_chromium_like "${CHROMIUM_LIKE_MAP[$pkg]:-$pkg}" "$root1"
  fi

  # Firefox in snap (common directory)
  root2="$HOME/snap/$pkg/common/.mozilla/firefox"
  dbg " checking snap/common $root2"
  if [[ -d "$root2" ]]; then # Проверяем наличие директории
    process_firefox "Firefox" "$root2"
  fi
done
dbg "Finished scanning snap"

# 3) flatpak-версии
dbg "Scanning flatpak"
for id in org.chromium.Chromium com.google.Chrome org.mozilla.firefox; do
  app="${id##*.}" # chromium, chrome, firefox
  # Путь к конфигу обычно в нижнем регистре
  local_app_name="${app,,}"
  root="$HOME/.var/app/$id/config/$local_app_name"
  dbg " checking flatpak $root"
  if [[ -f "$root/Local State" ]]; then
    process_chromium_like "${CHROMIUM_LIKE_MAP[$local_app_name]:-$app}" "$root"
  elif [[ -f "$root/profiles.ini" ]]; then # Firefox case
    process_firefox "Firefox" "$root"
  fi
done
dbg "Finished scanning flatpak"

# 4) классический Firefox
dbg "Checking classic Firefox"
ffdir="$HOME/.mozilla/firefox"
if [[ -f "$ffdir/profiles.ini" ]]; then
  process_firefox "Firefox" "$ffdir"
fi
dbg "Finished scanning classic Firefox"

# Итог сканирования
echo -e "${GREEN}browser_cache.conf has been updated!${NC}"
(( DEBUG )) && dbg "All browsers scanned successfully – OK"
echo -e "${GREEN}All browsers scanned successfully – OK${NC}"
