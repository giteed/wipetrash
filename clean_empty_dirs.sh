#!/usr/bin/env bash
# clean_empty_dirs.sh - удаление пустых папок с рандомизацией имен
# 1.0.0 - 31 Jul 2025

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
LOG_FILE="$SCRIPT_DIR/reports/empty_dirs_$(date '+%F-%H-%M-%S').log"

# Генерация случайного имени (12 символов)
generate_random_name() {
  tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1
}

# Основная функция обработки
process_empty_dirs() {
  local dirs=()
  
  # Загрузка путей из конфигов
  for conf in "$CONF_AUTO" "$CONF_MANUAL"; do
    [[ -f "$conf" ]] || continue
    while IFS='|' read -r path _; do
      [[ -z "$path" || "$path" == \#* ]] && continue
      dirs+=("$path")
    done <"$conf"
  done

  local total_removed=0

  for dir in "${dirs[@]}"; do
    [[ ! -d "$dir" ]] && continue
    
    echo -e "\n${GREEN}Проверка: $dir${NC}"
    local empty_dirs=()
    
    # Ищем пустые папки (включая вложенные)
    while IFS= read -r -d '' empty_dir; do
      empty_dirs+=("$empty_dir")
    done < <(find "$dir" -type d -empty -print0 2>/dev/null)

    local count=${#empty_dirs[@]}
    (( count == 0 )) && continue

    echo "Найдено пустых папок: $count"
    for empty_dir in "${empty_dirs[@]}"; do
      # Пропускаем корневые директории из конфигов
      [[ " ${dirs[@]} " =~ " $empty_dir " ]] && continue

      # Генерируем случайное имя
      random_name="$(generate_random_name)"
      new_path="$(dirname "$empty_dir")/$random_name"

      echo "Переименовываем: $empty_dir -> $new_path"
      if mv "$empty_dir" "$new_path"; then
        echo "Удаляем: $new_path"
        if rm -rf "$new_path"; then
          echo "Успешно удалено"
          ((total_removed++))
        else
          echo -e "${RED}Ошибка удаления${NC}"
        fi
      else
        echo -e "${RED}Ошибка переименования${NC}"
      fi
    done
  done

  echo -e "\n${GREEN}Итого удалено папок: $total_removed${NC}"
}

# Создаем директорию для логов
mkdir -p "$(dirname "$LOG_FILE")"

# Запуск с логированием
process_empty_dirs 2>&1 | tee "$LOG_FILE"
