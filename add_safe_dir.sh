#!/usr/bin/env bash
# add_safe_dir – добавить каталоги/файлы
# 1.1.0 — 29 Jul 2025

set -euo pipefail; IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/trash_manual.conf"
BACKUP="$CONF.bak.$(date +%s)"

[[ -f $CONF ]] || touch "$CONF"
cp -a -- "$CONF" "$BACKUP"
echo "• Резервная копия: $BACKUP"

echo "Вводите абсолютные пути (файлы или каталоги). Пустая строка — выход."
added=0
while true; do
  read -rp "Путь (q=выход): " path
  [[ -z $path || $path == q* ]] && break
  path=$(realpath -m "$path" 2>/dev/null || true)
  [[ -e $path ]] || { echo "  ✖ не существует"; continue; }
  grep -Fxq "$path|" "$CONF" && { echo "  • уже в списке"; continue; }
  echo "$path|" >>"$CONF"
  echo "  ✓ добавлено: $path"
  ((added++))
done
echo "Добавлено: $added"
