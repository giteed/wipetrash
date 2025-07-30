#!/usr/bin/env bash
# clean_trash – движок
# 5.2.0 — 30 Jul 2025

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

###############################################################################
# ── 0. гарантируем наличие wipe ─────────────────────────────────────────────
###############################################################################
ensure_wipe() {
    command -v wipe &>/dev/null && return
    echo -e "${YELLOW}Программа «wipe» не найдена.${NC}"
    if ! command -v apt-get &>/dev/null; then
        echo -e "${RED}Авто‑установка невозможна. Установите «wipe» вручную!${NC}"
        exit 1
    fi
    read -rp "Установить «wipe» через apt-get? [Y/n] " ans
    [[ ${ans:-Y} =~ ^[Nn]$ ]] && { echo "Отмена."; exit 1; }
    sudo apt-get update && sudo apt-get install -y wipe
}

###############################################################################
deny_match(){ local p=$1; [[ -f $CONF_DENY && $(grep -Fx "$p" "$CONF_DENY") ]] && return 0; [[ $p == / || $p == /home || $p == /root ]] && return 0; return 1; }

logfile=""
log(){ echo -e "$*" >>"$logfile"; }
err(){ echo -e "✖ $*" >>"$logfile"; }

wipe_one(){ wipe -f -q -Q 1 -- "$1" 2>>"$logfile" || rm -f -- "$1" 2>>"$logfile"; }

wipe_file(){ wipe_one "$1" && log "✓ файл: $1" || err "файл: $1"; }

wipe_dir_contents() {
    local d=$1 removed=0
    mapfile -d '' items < <(find "$d" -mindepth 1 -print0 2>/dev/null || true)
    local total=${#items[@]} i=0
    for p in "${items[@]}"; do
        ((i++))
        printf "\r${YELLOW}%s${NC}  %d/%d" "$d" "$i" "$total"
        if [[ -f $p || -L $p ]]; then
            wipe_file "$p" && ((removed++))
        else
            rm -rf -- "$p" 2>>"$logfile" && log "✓ каталог: $p" || err "каталог: $p"
        fi
    done
    [[ $total -gt 0 ]] && echo
    echo "$removed"
}

load_lists(){
    MAP_FILES=()
    for cfg in "$CONF_AUTO" "$CONF_MANUAL"; do
        [[ -r $cfg ]] || continue
        while IFS='|' read -r p _; do
            [[ -z $p || $p == \#* ]] && continue
            MAP_FILES+=("$p")
        done <"$cfg"
    done
}

run_clean(){
    local stamp=$(date '+%Y-%m-%d_%H-%M-%S')
    logfile="$REPORT_DIR/report_$stamp.log"; : >"$logfile"
    load_lists
    local removed=0

    for p in "${MAP_FILES[@]}"; do
        if deny_match "$p"; then log "⚠️  deny: $p"; continue; fi
        echo -e "${BLUE}--- $p ---${NC}"
        if [[ -f $p || -L $p ]]; then
            wipe_file "$p" && ((removed++))
        elif [[ -d $p ]]; then
            before=$(find "$p" ! -type d | wc -l)
            echo "до: $before объектов"
            n=$(wipe_dir_contents "$p"); ((removed+=n))
            after=$(find "$p" ! -type d | wc -l)
            echo "после: $after"
        else
            err "не найдено: $p"
        fi
    done

    log "Всего удалено: $removed"
    echo "$logfile"
}

repair_trash_dirs(){
    load_lists; local fixed=0
    for p in "${MAP_FILES[@]}"; do
        [[ $p != */Trash/files ]] && continue
        info="${p%/files}/info"
        for d in "$p" "$info"; do
            [[ -d $d ]] || { mkdir -p -- "$d" && chmod 700 -- "$d" && echo "Создано: $d" && ((fixed++)); }
        done
    done
    ((fixed)) && echo "Исправлено директорий: $fixed" || echo "Все корзины целы."
}

ensure_wipe
