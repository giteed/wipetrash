#!/usr/bin/env bash
# wipe_trash – меню
# 3.2.0 — 30 Jul 2025
# =====================================

set -euo pipefail
IFS=$'\n\t'

# ── цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── подготовка ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"   # даёт load_lists, run_clean, repair_trash_dirs
load_lists                             # заполняет MAP_FILES

ADD_SCRIPT="$SCRIPT_DIR/add_safe_dir.sh"
REPORT_DIR="$SCRIPT_DIR/reports"

#############################################################################
# вспомогательные функции
#############################################################################
human() {
    local s=$1 units=(B K M G T)
    for u in "${units[@]}"; do
        ((s < 1024)) && { printf "%d%s" "$s" "$u"; return; }
        s=$((s/1024))
    done
    printf "%dP" "$s"
}

scan() {
    local p=$1
    if [[ -d $p ]]; then
        local c b
        c=$(find "$p" ! -type d -print 2>/dev/null | wc -l)
        b=$(du -sb "$p" 2>/dev/null | cut -f1)
        echo "$c|$b"
    elif [[ -f $p || -L $p ]]; then
        local b
        b=$(du -b "$p" 2>/dev/null | cut -f1)
        echo "1|$b"
    else
        echo "0|0"
    fi
}

show_menu() {
    echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
    echo    "============================================  v3.2.0"
    echo -e "$SETUP_MSG\n"
    echo -e "  ${RED}1${NC}) Очистить ${CYAN}ВСЁ${NC} (корзины + history)\n"

    local n=2
    for p in "${MAP_FILES[@]}"; do
        printf "  ${CYAN}%d${NC}) Очистить: ${YELLOW}%s${NC}\n" "$n" "$p"
        ((n++))
    done

    printf "\n  ${CYAN}%d${NC}) Только history «Недавние файлы»\n" "$n"
    echo -e "  a) Добавить каталоги/файлы"
    echo -e "  v) Просмотреть отчёты"
    echo -e "  r) Проверить/починить структуру корзин"
    echo -e "  h) Help"
    echo -e "  q) Quit"
}

view_reports() {
    if ! ls -1 "$REPORT_DIR" 1>/dev/null 2>&1; then
        echo "Нет отчётов."; read -rp "Enter …"
        return
    fi
    select rep in "$REPORT_DIR"/*; do
        [[ -z ${rep:-} ]] && break
        less "$rep"
        read -rp "Удалить этот отчёт? [y/N] " ans
        [[ ${ans,,} == y ]] && rm -f -- "$rep"
        break
    done
}

help_screen() {
    less <<EOF
 wipe_trash — меню для безвозвратной очистки:

  1  — полная очистка (корзины + history)
  a  — добавить файлы/каталоги в ручной список (trash_manual.conf)
  v  — просмотреть или удалить отчёты
  r  — проверить/починить структуру корзин (создаёт недостающие files/info)
  q  — выход
EOF
}

#############################################################################
# основной цикл меню
#############################################################################
while true; do
    clear
    show_menu
    read -rp $'\n'"Выберите действие [Enter = 1]: " choice
    choice=${choice:-1}

    case $choice in
        1)
            log=$(run_clean)
            echo -e "\nОтчёт сохранён: $log"
            read -rp "Enter …"
            ;;

        a|A)
            "$ADD_SCRIPT"
            load_lists
            ;;

        v|V)
            view_reports
            ;;

        r|R)
            repair_trash_dirs
            read -rp "Enter …"
            ;;

        h|H)
            help_screen
            read -rp "Enter …"
            ;;

        q|Q)
            exit 0
            ;;

        ''|*[!0-9]*)
            echo "Неверный ввод!"
            read -rp "Enter …"
            ;;

        *)
            idx=$((choice - 2))
            if (( idx >= 0 && idx < ${#MAP_FILES[@]} )); then
                old_list=("${MAP_FILES[@]}")
                MAP_FILES=("${MAP_FILES[idx]}")        # временно чистим только одну цель
                echo -e "${YELLOW}Очистка: ${MAP_FILES[0]}${NC}"
                log=$(run_clean)
                MAP_FILES=("${old_list[@]}")           # восстанавливаем
                echo -e "\nОтчёт сохранён: $log"
                read -rp "Enter …"
            elif (( choice == (${#MAP_FILES[@]} + 2) )); then
                clean_history
                read -rp "Enter …"
            else
                echo "Неверный пункт!"
                read -rp "Enter …"
            fi
            ;;
    esac
done
