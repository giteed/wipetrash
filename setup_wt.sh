#!/usr/bin/env bash
# setup_wt.sh – авто‑конфигурирование wipe_trash
# 1.3.0 — 29 Jul 2025

UID_=$(id -u)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/trash_locations.conf"
DESKTOP="$HOME/.local/share/applications/wipe_trash.desktop"
ENGINE="$(realpath "$SCRIPT_DIR/wipe_trash.sh")"
SRC_ICON="$(realpath "$SCRIPT_DIR/Burn_Folder_128x128_43380.png")"
DEST_ICON="$HOME/.local/share/icons/wipe_trash.png"   # если понадобиться копия

# ── 1. Сканируем корзины ───────────────────────────────────────────────────
declare -A SEEN; LINES=()

add() { local f=$1 i=$2; [[ ${SEEN[$f]+yes} ]] && return; SEEN[$f]=1
         LINES+=("$f|$f|$i"); }

h_f="$HOME/.local/share/Trash/files"; h_i="$HOME/.local/share/Trash/info"
[[ -d $h_f && -d $h_i ]] && add "$h_f" "$h_i"

for base in /media /mnt /run/media; do
  [[ -d $base ]] || continue
  while IFS= read -r -d '' p; do
    t="$p/.Trash-$UID_"
    [[ -d $t/files && -d $t/info ]] && add "$t/files" "$t/info"
  done < <(find "$base" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null)
done

{
  echo "# generated $(date '+%F %T')"
  for l in "${LINES[@]}"; do echo "$l"; done
} >"$CONF"
echo "✓ Конфиг корзин: $CONF  (найдено: ${#LINES[@]})"

# ── 2. Проверка структуры (только сообщение) ───────────────────────────────
for l in "${LINES[@]}"; do
  IFS='|' read -r _ f i <<<"$l"
  [[ -d $f && -d $i ]] || echo "⚠️  Повреждена структура: $f"
done

# ── 3. Готовим иконку ───────────────────────────────────────────────────────
ICON_FIELD=""
if [[ $SRC_ICON == *" "* ]]; then
  mkdir -p "$(dirname "$DEST_ICON")"
  cp -f -- "$SRC_ICON" "$DEST_ICON"
  ICON_FIELD="Icon=wipe_trash"
else
  ICON_FIELD="Icon=$SRC_ICON"
fi

# ── 4. Пишем .desktop (если его нет) ───────────────────────────────────────
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
