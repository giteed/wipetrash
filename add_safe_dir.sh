#!/usr/bin/env bash
# add_safe_dir.sh – интерактивное добавление «безопасных» каталогов
# к списку очистки (trash_locations.conf).
# 29 Jul 2025

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/trash_locations.conf"
BACKUP="$CONF_FILE.bak.$(date +%s)"

[[ -f $CONF_FILE ]] || { echo "❌ Не найден $CONF_FILE – сначала запустите ./setup_wt.sh"; exit 1; }

echo "--------------------------------------------"
echo " ДОБАВЛЕНИЕ КАТАЛОГОВ ДЛЯ БЕЗОПАСНОЙ ОЧИСТКИ"
echo " (записи попадут в $CONF_FILE)"
echo " Введите абсолютные пути к каталогам."
echo " Пустая строка или «q» – выход."
echo "--------------------------------------------"

# делаем резервную копию
cp -a -- "$CONF_FILE" "$BACKUP"
echo "• Сделана резервная копия: $BACKUP"

added=0
while true; do
  read -rp "Путь к каталогу (q=выход): " dir
  [[ -z $dir || $dir == q || $dir == Q ]] && break

  dir="$(realpath -m "$dir" 2>/dev/null || true)"
  if [[ ! -d $dir ]]; then
    echo "  ✖ $dir — не каталог или не существует."
    continue
  fi

  # уже есть?
  if grep -F -q "|$dir|" "$CONF_FILE"; then
    echo "  • $dir уже присутствует в списке."
    continue
  fi

  echo "$dir|$dir|" >>"$CONF_FILE"
  echo "  ✓ Добавлено: $dir"
  ((added++))
done

if (( added )); then
  echo "--------------------------------------------"
  echo " Добавлено каталогов: $added"
  echo " Перезапустите меню wipe_trash, чтобы увидеть изменения."
else
  echo " Ничего не добавлено."
fi
