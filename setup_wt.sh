#!/usr/bin/env bash
# setup_wt.sh – авто‑настройка wipe_trash
# 1.4.1 — 30 Jul 2025

# ── 0. Переменные ──────────────────────────────────────────────────────────
TARGET_USER=${SUDO_USER:-$USER}
HOME_DIR=$(eval echo "~$TARGET_USER")
UID_=$(id -u "$TARGET_USER")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"

DESKTOP="$HOME/.local/share/applications/wipe_trash.desktop"
ENGINE="$(realpath "$SCRIPT_DIR/wipe_trash.sh")"
SRC_ICON="$(realpath "$SCRIPT_DIR/Burn_Folder_128x128_43380.png")"
DEST_ICON="$HOME/.local/share/icons/wipe_trash.png"

# ── 1. Ищем корзины ───────────────────────────────────────────────────────
declare -A SEEN
LINES=()

add() { local files=$1 info=$2
        [[ -z $files || ${SEEN[$files]+1} ]] && return
        SEEN[$files]=1
        LINES+=("$files|$files|$info")
      }

home_f="$HOME_DIR/.local/share/Trash/files"
home_i="$HOME_DIR/.local/share/Trash/info"
[[ -d $home_f && -d $home_i ]] && add "$home_f" "$home_i"

for base in /media /mnt /run/media; do
  [[ -d $base ]] || continue
  while IFS= read -r -d '' mp; do
    td="$mp/.Trash-$UID_"
    [[ -d $td/files && -d $td/info ]] && add "$td/files" "$td/info"
  done < <(find "$base" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null)
done

# ── 2. Пишем trash_auto.conf ───────────────────────────────────────────────
{
  echo "# generated $(date '+%F %T')"
  for l in "${LINES[@]}"; do echo "$l"; done
} >"$CONF_AUTO"
echo "✓ Конфиг корзин: $CONF_AUTO  (найдено: ${#LINES[@]})"

# ── 3. Создаём пустые файлы, если их нет ───────────────────────────────────
touch "$CONF_MANUAL" "$CONF_DENY"

# ── 4. Проверяем структуру ────────────────────────────────────────────────
for l in "${LINES[@]}"; do
  IFS='|' read -r _ files info <<<"$l"
  [[ -z $files ]] && continue                 # ←← исправление: пропуск пустых
  [[ -d $files && -d $info ]] || echo "⚠️  Повреждена структура: $files"
done

# ── 5. Иконка ──────────────────────────────────────────────────────────────
if [[ $SRC_ICON == *" "* ]]; then
  mkdir -p "$(dirname "$DEST_ICON")"
  cp -f -- "$SRC_ICON" "$DEST_ICON"
  ICON_FIELD="Icon=wipe_trash"
else
  ICON_FIELD="Icon=$SRC_ICON"
fi

# ── 6. .desktop ярлык ─────────────────────────────────────────────────────
make_desktop() {
cat >"$DESKTOP"<<EOF
[Desktop Entry]
Version=1.1
Type=Application
Name=WipeTrash
Comment=Безвозвратная очистка корзин + history
Exec=/usr/bin/env bash -c '"$ENGINE"'
$ICON_FIELD
Terminal=true
Categories=System;
StartupNotify=true
EOF
  update-desktop-database ~/.local/share/applications &>/dev/null || true
}

if [[ -f $DESKTOP ]]; then
  echo "• Ярлык уже существует: $DESKTOP"
else
  make_desktop
  echo "✓ Создан ярлык: $DESKTOP"
fi

# ── 7. Делаем все *.sh исполняемыми ───────────────────────────────────────
chmod +x "$SCRIPT_DIR"/*.sh
