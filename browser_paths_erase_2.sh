#!/bin/bash
# browser_paths_erase_2.sh - скрипт очистки кеша браузеров с перемещением в temp-папку
set -euo pipefail
IFS=$'\n\t'

# ────────────────────────────────────────────────────────────────────────────────
# Настройки
# ────────────────────────────────────────────────────────────────────────────────
RED='\033[1;91m'; GREEN='\033[1;92m'; YELLOW='\033[1;93m'
BLUE='\033[1;94m'; MAGENTA='\033[1;95m'; CYAN='\033[1;96m'; NC='\033[0m'

CONFIG_FILE="browser_cache.conf"
BASE_TEMP_DIR="tmp_browser_paths_erase"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_DIR="$BASE_TEMP_DIR/$TIMESTAMP"
LOG_DIR="tmp_browser_paths_erase"
LOG_FILE="$LOG_DIR/erase_${TIMESTAMP}.log"

# ────────────────────────────────────────────────────────────────────────────────
# Инициализация
# ────────────────────────────────────────────────────────────────────────────────
mkdir -p "$TEMP_DIR" || {
    echo -e "${RED}ОШИБКА: Не удалось создать $TEMP_DIR${NC}" >&2
    exit 1
}

mkdir -p "$LOG_DIR" || {
    echo -e "${RED}ОШИБКА: Не удалось создать $LOG_DIR${NC}" >&2
    exit 1
}

# Заголовок лог-файла
{
    echo "# Browser Cache Erase Log"
    echo "# Date: $(date)"
    echo "# Temp Directory: $TEMP_DIR"
    echo "# Format: original_path|temp_path|label"
    echo "#"
} > "$LOG_FILE"

# ────────────────────────────────────────────────────────────────────────────────
# Функции
# ────────────────────────────────────────────────────────────────────────────────
move_to_temp() {
    local src="$1"
    local label="$2"
    local filename=$(basename "$src")
    local temp_path="$TEMP_DIR/$filename"

    # Запись в лог перед действием
    echo "$src|$temp_path|$label" >> "$LOG_FILE"

    if [[ ! -e "$src" ]]; then
        echo -e "${YELLOW}Предупреждение: '$src' не существует${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    echo -e "${CYAN}Перемещаем: ${YELLOW}$label${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}Из: $src${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}В: $temp_path${NC}" | tee -a "$LOG_FILE"

    if mv -f "$src" "$temp_path"; then
        echo -e "${GREEN}Успешно перемещено!${NC}\n" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Ошибка перемещения!${NC}\n" >&2 | tee -a "$LOG_FILE"
        return 1
    fi
}

print_section() {
    echo -e "\n${MAGENTA}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

process_line() {
    local line="$1"
    local line_num="$2"
    
    # Пропускаем первые 2 строки и пустые строки
    ((line_num <= 2)) && return
    [[ -z "$line" ]] && return
    
    # Обработка секций
    if [[ "$line" == \#* ]]; then
        print_section "${line#*# }"
        return
    fi
    
    # Разбор строки конфига
    IFS='|' read -r path label mode <<< "$line"
    path=$(echo "$path" | xargs)
    label=$(echo "$label" | xargs)
    mode=$(echo "$mode" | xargs)
    
    # Вывод информации о файле
    echo -e "${CYAN}Файл: ${YELLOW}$label${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}Путь: $path${NC}" | tee -a "$LOG_FILE"
    echo -ne "Режим: " | tee -a "$LOG_FILE"
    
    case "$mode" in
        auto)
            echo -e "${GREEN}Автоудаление${NC}\n" | tee -a "$LOG_FILE"
            move_to_temp "$path" "$label"
            ;;
        ask)
            echo -e "${YELLOW}Требуется подтверждение${NC}" | tee -a "$LOG_FILE"
            exec 3<&0
            exec < /dev/tty
            
            while true; do
                read -p "Удалить? (y/N): " -n 1 -r
                echo
                case $REPLY in
                    [Yy]) 
                        echo -e "${GREEN}Удаление подтверждено${NC}\n" | tee -a "$LOG_FILE"
                        move_to_temp "$path" "$label"
                        break 
                        ;;
                    [Nn]|"") 
                        echo -e "${RED}Удаление отменено${NC}\n" | tee -a "$LOG_FILE"
                        break 
                        ;;
                    *) 
                        echo -e "${RED}Неверный ввод!${NC} Введите y или n" | tee -a "$LOG_FILE"
                        ;;
                esac
            done
            
            exec <&3
            exec 3<&-
            ;;
        skip)
            echo -e "${RED}Пропущено${NC}\n" | tee -a "$LOG_FILE"
            ;;
        *)
            echo -e "${RED}Неизвестный режим: $mode${NC}\n" | tee -a "$LOG_FILE"
            ;;
    esac
}

# ────────────────────────────────────────────────────────────────────────────────
# Основной код
# ────────────────────────────────────────────────────────────────────────────────
echo -e "\n${MAGENTA}===== НАЧАЛО ОЧИСТКИ КЕША БРАУЗЕРОВ =====${NC}" | tee -a "$LOG_FILE"
echo -e "${BLUE}Лог-файл: $LOG_FILE${NC}" | tee -a "$LOG_FILE"
echo -e "${BLUE}Временная папка: $TEMP_DIR${NC}" | tee -a "$LOG_FILE"

# Чтение конфига
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}ОШИБКА: Файл конфигурации $CONFIG_FILE не найден${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

mapfile -t config_lines < "$CONFIG_FILE"

# Обработка каждой строки
for i in "${!config_lines[@]}"; do
    process_line "${config_lines[i]}" "$((i+1))"
done

echo -e "${MAGENTA}===== ОЧИСТКА ЗАВЕРШЕНА =====${NC}\n" | tee -a "$LOG_FILE"
echo -e "${YELLOW}Перемещенные данные находятся в:${NC}" | tee -a "$LOG_FILE"
echo -e "${CYAN}$TEMP_DIR${NC}" | tee -a "$LOG_FILE"
echo -e "${YELLOW}Для отката выполните:${NC}" | tee -a "$LOG_FILE"
echo -e "${CYAN}./browser_paths_erase_rollback.sh $LOG_FILE${NC}" | tee -a "$LOG_FILE"
