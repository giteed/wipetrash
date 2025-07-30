#!/usr/bin/env bash
# wipe_trash.sh - главное меню
# 3.2.8 - 31 Jul 2025

source "$(dirname "${BASH_SOURCE[0]}")/wipe_functions.sh"

ADD_SCRIPT="$SCRIPT_DIR/add_safe_dir.sh"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

clean_history() {
  rm -f ~/.local/share/recently-used.xbel 2>/dev/null || true
  echo -e "${GREEN}История очищена.${NC}"
}

show_menu() {
  clear
  echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
  echo    "============================================  v3.2.8"
  echo -e "$SETUP_MSG\n"
  echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"
  local n=2
  for path in "${MAP_FILES[@]}"; do
    printf "  ${CYAN}%d${NC}) Очистить: ${YELLOW}%s${NC}\n" "$n" "$path"
    ((n++))
  done
  printf "\n  ${CYAN}%d${NC}) Только history «Недавние файлы»\n" "$n"
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
  if [[ ! -f "$SCRIPT_DIR/clean_trash.sh" ]]; then
    echo -e "${RED}Ошибка: clean_trash.sh не найден${NC}" >&2
    return 1
  fi
  log_file=$("$SCRIPT_DIR/clean_trash.sh")
  echo "$log_file"
}

repair_trash_dirs() {
  # Делегируем починку основному скрипту
  "$SCRIPT_DIR/clean_trash.sh" --repair
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
        log_file=$(run_clean)
        clean_history
        echo -e "\nОтчёт: $log_file"
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
        repair_trash_dirs
        read -rp "Нажмите Enter для продолжения..."
        ;;
      h|H)
        show_help
        ;;
      q|Q)
        exit 0
        ;;
      *[!0-9]*)
        echo "Неверный ввод!"
        read -rp "Нажмите Enter для продолжения..."
        ;;
      *)
        local idx=$((choice - 2))
        if (( idx >= 0 && idx < ${#MAP_FILES[@]} )); then
          local target="${MAP_FILES[idx]}"
          echo -e "${YELLOW}Очистка: $target${NC}"
          MAP_FILES=("$target")
          log_file=$(run_clean)
          load_lists || true
          echo -e "\nОтчёт: $log_file"
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
