#!/bin/bash
# clean_log.sh - правильная очистка лога
if [[ $# -ne 1 ]]; then
    echo "Использование: $0 <лог-файл>"
    exit 1
fi

LOG_FILE="$1"
CLEANED_LOG="$LOG_FILE.cleaned"

# Очищаем только строки с путями (формат: исходный_путь|временный_путь|метка)
grep -E '^/[^|]+\|tmp_browser_paths_erase/[^|]+\|' "$LOG_FILE" > "$CLEANED_LOG"

if [[ -s "$CLEANED_LOG" ]]; then
    echo "Лог очищен: $CLEANED_LOG"
    exit 0
else
    echo "Ошибка: не удалось очистить лог" >&2
    rm -f "$CLEANED_LOG"
    exit 1
fi
