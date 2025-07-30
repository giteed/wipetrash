#!/usr/bin/env bash
# clean_trash.sh – движок очистки
# Версия: 4.4.0 (29 Jul 2025)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then set -euo pipefail; fi
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
trap 'tput cnorm; echo -e "\n${RED}Прервано!${NC}"; exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/trash_locations.conf"
SETUP="$SCRIPT_DIR/setup_wt.sh"

###############################################################################
install_utils() {
    command -v wipe &>/dev/null && return
    echo -e "${YELLOW}Устанавливаю «wipe»…${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y wipe
    else
        echo -e "${RED}Не могу установить «wipe».${NC}"; exit 1
    fi
}

human() { local s=$1 u=(B K M G T); for x in "${u[@]}"; do ((s<1024))&&{ printf "%d%s" "$s" "$x"; return; }; s=$((s/1024)); done; printf "%dP" "$s"; }

clean_with_progress() {
    local dir=$1; mapfile -d '' items < <(find "$dir" ! -type d -print0 2>/dev/null)
    local total=${#items[@]}; ((total==0)) && { echo -e "${GREEN}Пусто: $dir${NC}"; return; }
    echo -e "${YELLOW}Очистка: $dir (${total})${NC}"; tput civis
    local i f; for ((i=1;i<=total;i++)); do f="${items[i-1]}"
        printf "\rУдаляем [%d/%d] %s" "$i" "$total" "$(basename "$f")"
        [[ -f $f ]] && { wipe -f -q -Q 1 -- "$f" 2>/dev/null || rm -f -- "$f"; } \
                     || rm -f -- "$f"
    done; echo; tput cnorm
    find "$dir" -type d -empty -delete 2>/dev/null
    echo -e "${GREEN}Готово.${NC}"
}

clean_trash() { [[ -d $1 ]] && clean_with_progress "$1"; [[ -d $2 ]] && clean_with_progress "$2"; }

clean_history() {
    echo -e "${YELLOW}Очистка history «Недавние файлы»…${NC}"
    rm -vf ~/.local/share/recently-used.xbel 2>/dev/null || true
    echo -e "${GREEN}История очищена.${NC}"
}

###############################################################################
load_config() {
    [[ -r $CONF_FILE ]] || "$SETUP" >/dev/null
    LABELS=(); FILES_DIRS=(); INFO_DIRS=(); declare -A SEEN
    while IFS='|' read -r _files files info; do
        [[ $_files == \#* ]] && continue
        [[ -n ${SEEN[$files]+1} ]] && continue
        SEEN[$files]=1
        LABELS+=("$files"); FILES_DIRS+=("$files"); INFO_DIRS+=("$info")
    done <"$CONF_FILE"
    (( ${#LABELS[@]} )) || { echo "❌ Корзины не найдены."; exit 1; }
}

###############################################################################
auto_mode() {
    [[ ${#LABELS[@]} -eq 0 ]] && load_config
    echo -e "${GREEN}========  ПОЛНАЯ ОЧИСТКА  ========${NC}"
    local i; for ((i=0;i<${#LABELS[@]};i++)); do
        clean_trash "${FILES_DIRS[i]}" "${INFO_DIRS[i]}"
    done
    clean_history
    echo -e "${GREEN}Завершено.${NC}"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && { install_utils; load_config; auto_mode; }
