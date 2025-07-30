#!/usr/bin/env bash
# wipe_trash – меню
# 3.2.5 — 30 Jul 2025
# =====================================

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"

ensure_wipe
load_lists || true                # ← игнорируем ненулевой код

ADD="$SCRIPT_DIR/add_safe_dir.sh"
REPORT_DIR="$SCRIPT_DIR/reports"

clean_history(){ rm -f ~/.local/share/recently-used.xbel 2>/dev/null || true; echo -e "${GREEN}История очищена.${NC}"; }

show(){ echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
        echo    "============================================  v3.2.5"
        echo -e "$SETUP_MSG\n"
        echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"
        n=2; for p in "${MAP_FILES[@]}"; do printf "  ${CYAN}%d${NC}) Очистить: ${YELLOW}%s${NC}\n" $n "$p"; ((n++)); done
        printf "\n  ${CYAN}%d${NC}) Только history «Недавние файлы»\n" $n
        echo -e "  a) Добавить каталоги/файлы\n  v) Просмотреть отчёты\n  r) Проверить/починить структуру\n  h) Help\n  q) Quit"; }

view_reports(){ ls -1 "$REPORT_DIR" &>/dev/null || { echo "Нет отчётов."; read; return; }
                select f in "$REPORT_DIR"/*; do [[ -z $f ]]&&break; less "$f"; read -rp "Удалить? [y/N] " a; [[ ${a,,} == y ]]&&rm -f "$f"; break; done; }

help(){ less <<<"1 — очистить всё; a — добавить пути; v — отчёты; r — починка; q — выход"; }

while true; do
  clear; show
  read -rp $'\n'"Выберите действие [Enter = 1]: " ch; ch=${ch:-1}
  case $ch in
    1) log=$(run_clean); echo -e "\nОтчёт: $log"; read ;;
    a|A) "$ADD"; load_lists || true ;;
    v|V) view_reports ;;
    r|R) repair_trash_dirs; read ;;
    h|H) help; read ;;
    q|Q) exit 0 ;;
    ''|*[!0-9]* ) echo "Неверный ввод!"; read ;;
    * ) idx=$((ch-2))
        if (( idx>=0 && idx<${#MAP_FILES[@]} )); then
          single=("${MAP_FILES[idx]}"); MAP_FILES=("${single[@]}")
          echo -e "${YELLOW}Очистка: ${single[0]}${NC}"
          log=$(run_clean); load_lists || true
          echo -e "\nОтчёт: $log"; read
        elif (( ch == (${#MAP_FILES[@]} + 2) )); then
          clean_history; read
        else echo "Неверный пункт!"; read; fi ;;
  esac
done
