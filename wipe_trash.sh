#!/usr/bin/env bash
# wipe_trash – меню очистки
# 3.0.1  — 29 Jul 2025
# =====================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"
load_lists                         # из clean_trash.sh

ADD="$SCRIPT_DIR/add_safe_dir.sh"
REPORT_DIR="$SCRIPT_DIR/reports"

human(){ local s=$1 u=(B K M G T);for x in "${u[@]}";do((s<1024))&&{printf "%d%s" "$s" "$x";return;};s=$((s/1024));done;printf "%dP" "$s";}
scan(){ [[ -d $1 ]]||{echo "0|0";return;};local c b;c=$(find "$1" ! -type d -print 2>/dev/null|wc -l);b=$(du -sb "$1" 2>/dev/null|cut -f1);echo "$c|$b";}

show_menu(){
  echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
  echo    "============================================"
  echo -e "$SETUP_MSG\n"
  echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"
  local n=2
  for p in "${MAP_FILES[@]}";do printf "  ${CYAN}%d${NC}) Очистить: ${YELLOW}%s${NC}\n" $n "$p";((n++));done
  printf "\n  ${CYAN}%d${NC}) Только history «Недавние файлы»\n" $n
  echo -e "  a) Добавить каталоги/файлы"
  echo -e "  v) Просмотреть отчёты"
  echo -e "  r) Проверить/починить структуру"
  echo -e "  h) Help"
  echo -e "  q) Quit"
}

view_reports(){
  ls -1 "$REPORT_DIR" 2>/dev/null || { echo "Нет отчётов."; read; return; }
  select rep in "$REPORT_DIR"/*;do
    [[ -z $rep ]]&&break
    less "$rep"
    read -rp "Удалить этот отчёт? [y/N] " ans
    [[ ${ans,,} == y ]]&&rm -f -- "$rep"
    break
  done
}

while true;do
  clear;show_menu
  read -rp $'\n'"Выберите действие [Enter = 1]: " ch
  ch=${ch:-1}

  BEFORE=();SIZE=()
  for d in "${MAP_FILES[@]}";do IFS='|' read -r c b<<<"$(scan "$d")";BEFORE+=("$c");SIZE+=("$b");done

  case $ch in
    1) logfile=$(run_clean);echo -e "\nОтчёт: $logfile";read -rp "Enter …";;
    a|A) "$ADD";load_lists;;                               # перечитываем списки
    v|V) view_reports;;
    r|R) repair;continue;;                                # ——— ПРАВИЛЬНОЕ МЕСТО
    h|H) less <<EOF
Help:
  1  — полная очистка корзин + history.
  a  — добавить пути (файлы/каталоги) в ручной список.
  v  — просмотреть/удалить отчёты.
  r  — проверить и (по желанию) починить структуру корзин.
EOF
         read;;
    q|Q) exit 0;;
    ''|*[!0-9]*) echo "Неверный ввод!";read;continue;;    # универсальный шаблон ТЕПЕРЬ НИЖЕ r|R
    *)
      idx=$((ch-2))
      if (( idx>=0 && idx<${#MAP_FILES[@]} ));then
        echo -e "${YELLOW}Очистка: ${MAP_FILES[idx]}${NC}"
        logfile=$(run_clean)
        echo -e "\nОтчёт: $logfile";read -rp "Enter …"
      elif (( ch == (${#MAP_FILES[@]}+2) ));then
        clean_history;read
      else
        echo "Неверный пункт!";read
      fi;;
  esac
done
