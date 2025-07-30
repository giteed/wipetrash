#!/usr/bin/env bash
# wipe_trash – меню очистки
# 3.0.2  — 29 Jul 2025
# =====================================

set -euo pipefail
IFS=$'\n\t'

# ── цвета ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── подготовка ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"   # даёт load_lists, run_clean, …
load_lists

ADD_SCRIPT="$SCRIPT_DIR/add_safe_dir.sh"
REPORT_DIR="$SCRIPT_DIR/reports"

# ── вспомогательные функции ──────────────────────────────────────────────
human() {
    local s=$1
    local units=(B K M G T)
    for u in "${units[@]}"; do
        if (( s < 1024 )); then
            printf "%d%s" "$s" "$u"
            return
        fi
        s=$((s/1024))
    done
    printf "%dP" "$s"
}

scan() {
    # → «count|bytes»
    local path=$1
    if [[ -d $path ]]; then
        local c b
        c=$(find "$path" ! -type d -print 2>/dev/null | wc -l)
        b=$(du -sb "$path" 2>/dev/null | cut -f1)
        echo "$c|$b"
    elif [[ -f $path || -L $path ]]; then
        local s
        s=$(du -b "$path" 2>/dev/null | cut -f1)
        echo "1|$s"
    else
        echo "0|0"
    fi
}

show_menu() {
    echo -e "${BLUE}===========  W I P E   T R A S H  ===========${NC}"
    echo    "============================================"
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
    echo -e "  r) Проверить/починить структуру"
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

repair() {
    echo
    "$SCRIPT_DIR"/clean_trash.sh auto_mode >/dev/null   # для структуры корзин
    read -rp "Enter …"
}

help_screen() {
cat <<EOF

 wipe_trash — меню для безвозвратной очистки корзин (.Trash-UID),
              ручных путей и файла history «Недавние файлы».

  1  — полная очистка (все корзины + history)
  a  — добавить файлы/каталоги в ручной список
  v  — посмотреть/удалить отчёты
  r  — проверить/починить структуру корзин
  h  — эта справка
  q  — выход

EOF
read -rp "Enter …"
}

# ── цикл меню ──────────────────────────────────────────────────────────────
while true; do
    clear
    show_menu
    read -rp $'\n'"Выберите действие [Enter = 1]: " choice
    choice=${choice:-1}

    # снимок «до» — используется для мини‑отчёта
    BEFORE_CNT=(); BEFORE_SZ=()
    for p in "${MAP_FILES[@]}"; do
        IFS='|' read -r c b <<<"$(scan "$p")"
        BEFORE_CNT+=("$c"); BEFORE_SZ+=("$b")
    done

    case $choice in
        1 )
            logfile=$(run_clean)
            echo -e "\nОтчёт сохранён: $logfile"
            read -rp "Enter …"
            ;;
        a|A )
            "$ADD_SCRIPT"
            load_lists             # перечитываем списки
            ;;
        v|V ) view_reports ;;
        r|R ) repair; continue ;;
        h|H ) help_screen; continue ;;
        q|Q ) exit 0 ;;

        ''|*[!0-9]* )
            echo "Неверный ввод!"; read -rp "Enter …"; continue ;;
        * )
            idx=$((choice-2))
            if (( idx>=0 && idx<${#MAP_FILES[@]} )); then
                echo -e "${YELLOW}Очистка: ${MAP_FILES[idx]}${NC}"
                logfile=$(run_clean)
                echo -e "\nОтчёт сохранён: $logfile"
                read -rp "Enter …"
            elif (( choice == (${#MAP_FILES[@]} + 2) )); then
                clean_history
                read -rp "Enter …"
            else
                echo "Неверный пункт!"; read -rp "Enter …"
            fi
            ;;
    esac
done
