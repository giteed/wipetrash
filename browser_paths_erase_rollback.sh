#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Проверяет все .sh файлы на наличие прав на выполнение и назначает их, если у какого-либо файла таких прав нет
for file in *.sh; do [ ! -x "$file" ] && chmod +x *.sh; done

RED='\033[1;91m'; GREEN='\033[1;92m'; YELLOW='\033[1;93m'; NC='\033[0m'
BASE_DIR="tmp_browser_paths_erase"

if [[ $# -ne 1 ]]; then
    echo -e "${YELLOW}Использование:${NC} $0 ${BASE_DIR}/erase_ДатаВремя.log"
    exit 1
fi

LOG_FILE="$1"
SESSION_ID=$(basename "$LOG_FILE" .log | sed 's/^erase_//')
CLEANED_LOG="$LOG_FILE.cleaned"
TEMP_DIR="$BASE_DIR/$SESSION_ID"

# 1. Очищаем лог
if ! ./clean_log.sh "$LOG_FILE"; then
    echo -e "${RED}ОШИБКА: Неверный формат лога${NC}" >&2
    exit 1
fi

# 2. Проверяем файлы для восстановления
echo -e "${YELLOW}Файлы для восстановления:${NC}"
while IFS='|' read -r original temp label; do
    echo -e "  ${GREEN}$label${NC}"
    echo -e "  Из: $temp"
    echo -e "  В: $original"
    echo
done < "$CLEANED_LOG"

# 3. Подтверждение
read -rp "Выполнить откат? (y/N): " answer
[[ "$answer" =~ ^[Yy] ]] || exit 0

# 4. Восстановление
while IFS='|' read -r original temp label; do
    echo -n "Восстановление $label... "
    if mv -f "$temp" "$original"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ОШИБКА${NC}"
    fi
done < "$CLEANED_LOG"

echo -e "${GREEN}Откат завершен.${NC}"
echo "Можно удалить временные файлы:"
echo "rm -rf '$TEMP_DIR' '$LOG_FILE' '$CLEANED_LOG'"
