#!/usr/bin/env bash
# wipe_trash.sh - главное меню
# 3.3.0 - 31 Jul 2025

source "$(dirname "${BASH_SOURCE[0]}")/wipe_functions.sh"

ADD_SCRIPT="$SCRIPT_DIR/add_safe_dir.sh"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"
# --- Добавлено ---
BROWSER_CLEAN_SCRIPT="$SCRIPT_DIR/browser_paths_erase.sh"
# -----------------

clean_history() {
  rm -f ~/.local/share/recently-used.xbel 2>/dev/null || true
  echo -e "${GREEN}История очищена.${NC}"
}

show_menu() {
  clear
  echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
  echo    "============================================  v3.3.0"
  echo -e "$SETUP_MSG\n"
  echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"
  local n=2
  for path in "${MAP_FILES[@]}"; do
    printf "  ${CYAN}%d${NC}) Очистить: ${YELLOW}%s${NC}\n" "$n" "$path"
    ((n++))
  done
  printf "\n  ${CYAN}%d${NC}) Только history «Недавние файлы»\n" "$n"
  # --- Изменено ---
  echo -e "  ${CYAN}b${NC}) Очистить кэш браузеров (настройка)"
  # -----------------
  echo -e "  a) Добавить каталоги/файлы\n  v) Просмотреть отчёты\n  r) Проверить/починить структуру\n  h) Help\n  q) Quit"
}

view_reports() {
  if ! ls -1 "$REPORT_DIR"/*.log &>/dev/null; then
    echo "Нет отчётов."
    read -rp "Нажмите Enter для продолжения..."
    return
  fi
  select report in "$REPORT_DIR"/*.log; do
    [[ -z "$report" ]] && break
    less "$report"
    read -rp "Удалить отчёт? [y/N] " answer
    [[ ${answer,,} == y ]] && rm -f "$report"
    break
  done
}

show_help() {
  less <<EOF
1 — очистить всё
a — добавить пути
v — просмотреть отчёты
r — починка структуры
q — выход
EOF
}

run_clean() {
  # Очистка с выводом прогресса
  log_file=$("$SCRIPT_DIR/clean_trash.sh" "$@")
  echo -e "\nОтчёт: $log_file"
}

main() {
  init_dirs
  ensure_wipe
  load_lists || {
    echo -e "${RED}Ошибка загрузки конфигов!${NC}" >&2
    exit 1
  }

  while true; do
    show_menu
    read -rp $'\n'"Выберите действие [Enter = 1]: " choice
    choice=${choice:-1}

    case "$choice" in
      1)
        # Исправлено: передаем все пути из MAP_FILES
        run_clean "${MAP_FILES[@]}"
        clean_history
        read -rp "Нажмите Enter для продолжения..."
        ;;
      a|A)
        "$ADD_SCRIPT"
        load_lists || true
        ;;
      v|V)
        view_reports
        ;;
      r|R)
        "$SCRIPT_DIR/clean_trash.sh" --repair
        read -rp "Нажмите Enter для продолжения..."
        ;;
      h|H)
        show_help
        read -rp "Нажмите Enter для продолжения..."
        ;;
      q|Q)
        exit 0
        ;;
      # --- Изменено ---
      b|B)
        echo -e "${YELLOW}Запуск очистки кэша браузеров (dry-run)...${NC}"
        if [[ -x "$BROWSER_CLEAN_SCRIPT" ]]; then
            # Всегда добавляем --debug для тестирования
            "$BROWSER_CLEAN_SCRIPT" --debug  # <-- Теперь debug будет всегда
        else
            echo -e "${RED}Ошибка: Скрипт '$BROWSER_CLEAN_SCRIPT' не найден или не является исполняемым.${NC}" >&2
        fi
        read -rp "Нажмите Enter для продолжения..."
        ;;
      # -----------------
      *[!0-9]*)
        echo "Неверный ввод!"
        read -rp "Нажмите Enter для продолжения..."
        ;;
      *)
        local idx=$((choice - 2))
        if (( idx >= 0 && idx < ${#MAP_FILES[@]} )); then
          local target="${MAP_FILES[idx]}"
          echo -e "${YELLOW}Очистка только: $target${NC}"
          run_clean "$target"
          read -rp "Нажмите Enter для продолжения..."
        elif (( choice == (${#MAP_FILES[@]} + 2) )); then
          clean_history
          read -rp "Нажмите Enter для продолжения..."
        else
          echo "Неверный пункт!"
          read -rp "Нажмите Enter для продолжения..."
        fi
        ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
