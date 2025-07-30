#!/usr/bin/env bash
# wipe_trash – меню
# 3.0.0 — 29 Jul 2025
# =====================================

# ← цвета из блока 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"

load_lists   # из clean_trash

ADD="$SCRIPT_DIR/add_safe_dir.sh"

show_menu() {
  echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
  echo    "============================================"
  echo -e "$SETUP_MSG\n"
  echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"
  local n=2
  for p in "${MAP_FILES[@]}"; do
    printf "  ${CYAN}%d${NC}) Очистить: ${YELLOW}%s${NC}\n" $n "$p"
    ((n++))
  done
  printf "\n  ${CYAN}%d${NC}) Только history «Недавние файлы»\n" $n
  echo -e "  a) Добавить каталоги/файлы"
  echo -e "  v) Просмотреть отчёты"
  echo -e "  r) Проверить/починить структуру"
  echo -e "  h) Help"
  echo -e "  q) Quit"
}

view_reports() {
  ls -1 "$REPORT_DIR" 2>/dev/null || { echo "Нет отчётов."; read; return; }
  select rep in "$REPORT_DIR"/*; do
    [[ -z $rep ]] && break
    less "$rep"
    read -rp "Удалить этот отчёт? [y/N] " ans
    [[ ${ans,,} == y ]] && rm -f -- "$rep"
    break
  done
}

while true; do
  clear; show_menu
  read -rp $'\n'"Выберите действие [Enter = 1]: " ch
  ch=${ch:-1}
  case $ch in
    1) logfile=$(run_clean); echo -e "\nОтчёт: $logfile"; read -rp "Enter …";;
    a|A) "$ADD"; load_lists ;;
    v|V) view_reports ;;
    h|H) less <<EOF
Help:
  1  — полная очистка корзин + history.
  a  — добавить пути (файлы/каталоги) в ручной список.
  v  — просмотреть/удалить отчёты.
  r  — проверить структуру корзин.
EOF
          read ;;
    q|Q) exit 0 ;;
    *)   if [[ $ch =~ ^[0-9]+$ ]]; then
           idx=$((ch-2))
           if (( idx>=0 && idx<${#MAP_FILES[@]} )); then
             echo -e "${YELLOW}Очистка: ${MAP_FILES[idx]}${NC}"
             logfile=$(run_clean)   # переиспользуем движок, он сам отфильтрует
             echo -e "\nОтчёт: $logfile"; read -rp "Enter …"
           elif (( ch == (${#MAP_FILES[@]} + 2) )); then
             clean_history; read
           else
             echo "Неверный пункт!" ; read
           fi
         else
           echo "Неверный ввод!"; read
         fi ;;
  esac
done
