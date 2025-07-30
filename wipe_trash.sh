#!/usr/bin/env bash
# wipe_trash – меню
# 3.2.2  — 30 Jul 2025
# =====================================

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"
load_lists

ADD_SCRIPT="$SCRIPT_DIR/add_safe_dir.sh"
REPORT_DIR="$SCRIPT_DIR/reports"

show() {
  echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
  echo    "============================================  v3.2.2"
  echo -e "$SETUP_MSG\n"
  echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"
  n=2
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
  if ! ls -1 "$REPORT_DIR" 1>/dev/null 2>&1; then
      echo "Нет отчётов."
      read -rp "Enter …"
      return
  fi
  select f in "$REPORT_DIR"/*; do
      [[ -z $f ]] && break
      less "$f"
      read -rp "Удалить? [y/N] " a
      [[ ${a,,} == y ]] && rm -f "$f"
      break
  done
}

help() { less <<<"1 — очистить всё; a — добавить пути; v — отчёты; r — починка; q — выход"; }

while true; do
  clear; show
  read -rp $'\n'"Выберите действие [Enter = 1]: " ch; ch=${ch:-1}
  case $ch in
    1) log=$(run_clean); echo -e "\nОтчёт: $log"; read ;;
    a|A) "$ADD_SCRIPT"; load_lists ;;
    v|V) view_reports ;;
    r|R) repair_trash_dirs; read ;;
    h|H) help; read ;;
    q|Q) exit 0 ;;
    ''|*[!0-9]*) echo "Неверный ввод!"; read ;;
    *)
        idx=$((ch-2))
        if (( idx>=0 && idx<${#MAP_FILES[@]} )); then
            one=("${MAP_FILES[idx]}"); MAP_FILES=("${one[@]}")
            echo -e "${YELLOW}Очистка: ${one[0]}${NC}"
            log=$(run_clean); load_lists
            echo -e "\nОтчёт: $log"; read
        elif (( ch == (${#MAP_FILES[@]} + 2) )); then
            clean_history; read
        else
            echo "Неверный пункт!"; read
        fi ;;
  esac
done
