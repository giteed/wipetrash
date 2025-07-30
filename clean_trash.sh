#!/usr/bin/env bash
# clean_trash – движок (wipe + rm-fallback по запросу)
# 5.4.4 — 31 Jul 2025

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"

# Создаем директорию для отчетов с проверкой
mkdir -p "$REPORT_DIR" || {
  echo -e "${RED}Ошибка: не удалось создать $REPORT_DIR${NC}" >&2
  exit 1
}

WIPE_PASSES="${WIPE_PASSES:-1}"
USE_RM_FALLBACK="${USE_RM_FALLBACK:-0}"

ensure_wipe() {
  if ! command -v wipe &>/dev/null; then
    echo -e "${RED}✖ Ошибка: «wipe» не установлен.${NC}" >&2
    if command -v apt-get &>/dev/null; then
      read -rp "Установить «wipe» через apt-get? [Y/n] " ans
      [[ ${ans:-Y} =~ ^[Nn]$ ]] && exit 1
      sudo apt-get update && sudo apt-get install -y wipe || exit 1
    else
      echo -e "${RED}Установите «wipe» вручную!${NC}" >&2
      exit 1
    fi
  fi
  echo -e "${GREEN}✓ wipe: $(command -v wipe)${NC}"
}

deny_match() {
  [[ -f "$CONF_DENY" ]] && grep -Fxq -- "$1" "$CONF_DENY" || 
  [[ "$1" == / || "$1" == /home || "$1" == /root ]]
}

log() { echo -e "$*" >>"$logfile"; }
err() { echo -e "✖ $*" >>"$logfile"; }

ask_fallback() {
  (( USE_RM_FALLBACK )) && return 0
  read -rp $'\n'"wipe не смог удалить файл. Включить запасной rm? [y/N] " a
  [[ ${a,,} == y ]] && { USE_RM_FALLBACK=1; export USE_RM_FALLBACK; }
}

wipe_one() {
  local file="$1"
  if wipe -f -q -Q "$WIPE_PASSES" -- "$file" >>"$logfile" 2>&1; then
    log "wipe файл: $file"
    return 0
  else
    err "wipe-error: $file"
    ask_fallback
    if (( USE_RM_FALLBACK )); then
      rm -f -- "$file" 2>>"$logfile" && log "rm файл: $file" || err "rm-error: $file"
    fi
    return 1
  fi
}

wipe_dir_contents() {
  local dir="$1"
  local removed_files=0
  local removed_dirs=0
  
  # Удаление файлов
  echo -e "${YELLOW}Удаление файлов в: $dir${NC}"
  while IFS= read -r -d $'\0' file; do
    wipe_one "$file" && ((removed_files++))
  done < <(find "$dir" -type f -print0 2>/dev/null)

  # Удаление пустых подпапок (кроме корневой)
  echo -e "${YELLOW}Поиск пустых подпапок в: $dir${NC}"
  while IFS= read -r -d $'\0' subdir; do
    if [[ "$subdir" != "$dir" ]]; then
      random_name="deleted_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
      new_path="$(dirname "$subdir")/$random_name"
      
      echo -e "Обработка: $subdir"
      if mv "$subdir" "$new_path" 2>/dev/null; then
        if rm -rf "$new_path" 2>/dev/null; then
          echo -e "${GREEN}Удалено: $subdir${NC}"
          ((removed_dirs++))
        else
          echo -e "${RED}Ошибка удаления: $new_path${NC}"
        fi
      else
        echo -e "${RED}Ошибка переименования: $subdir${NC}"
      fi
    fi
  done < <(find "$dir" -type d -empty -print0 2>/dev/null | sort -rz)

  # Возвращаем общее количество удаленных объектов
  echo -e "${GREEN}Удалено файлов: $removed_files, папок: $removed_dirs${NC}"
  echo $((removed_files + removed_dirs))
}

run_clean() {
  logfile="$REPORT_DIR/report_$(date '+%F-%H-%M-%S').log"
  : >"$logfile"
  load_lists
  local removed=0

  for path in "${MAP_FILES[@]}"; do
    if deny_match "$path"; then
      log "⚠️  deny: $path"
      continue
    fi
    
    echo -e "\n${GREEN}--- $path ---${NC}"
    if [[ -f "$path" || -L "$path" ]]; then
      wipe_one "$path" && ((removed++))
    elif [[ -d "$path" ]]; then
      before=$(find "$path" -type f | wc -l)
      echo "Файлов до: $before"
      n=$(wipe_dir_contents "$path")
      ((removed += n))
      after=$(find "$path" -type f | wc -l)
      echo "Файлов после: $after"
    else
      err "не найдено: $path"
    fi
  done

  log "Всего удалено объектов: $removed"
  echo "$logfile"
}
repair_trash_dirs() {
  load_lists
  local fixed=0
  for path in "${MAP_FILES[@]}"; do
    [[ "$path" != */Trash/files ]] && continue
    info_dir="${path%/files}/info"
    for dir in "$path" "$info_dir"; do
      if [[ ! -d "$dir" ]]; then
        mkdir -p -- "$dir" && chmod 700 -- "$dir"
        echo "Создано: $dir"
        ((fixed++))
      fi
    done
  done
  ((fixed)) && echo "Исправлено: $fixed" || echo "Все корзины целы."
}

# Инициализация только при прямом запуске
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  ensure_wipe
fi
