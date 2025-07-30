#!/usr/bin/env bash
# clean_trash – движок (wipe + прогресс + отчёт)
# 5.2.3 — 30 Jul 2025

set -euo pipefail
IFS=$'\n\t'

# ── цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── пути ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

###############################################################################
# 0. гарантируем наличие wipe
###############################################################################
ensure_wipe() {
    command -v wipe &>/dev/null && return
    echo -e "${YELLOW}«wipe» не найден.${NC}"
    if ! command -v apt-get &>/dev/null; then
        echo -e "${RED}apt‑get недоступен. Установите «wipe» вручную!${NC}"
        exit 1
    fi
    read -rp "Установить «wipe» через apt‑get? [Y/n] " ans
    [[ ${ans:-Y} =~ ^[Nn]$ ]] && { echo "Отмена."; exit 1; }
    sudo apt-get update && sudo apt-get install -y wipe
}

###############################################################################
# 1. утилиты
###############################################################################
deny_match() {
    [[ -f $CONF_DENY ]] && grep -Fxq "$1" "$CONF_DENY" && return 0
    [[ $1 == / || $1 == /home || $1 == /root ]]
}

logfile=""
log() {  echo -e "$*" >>"$logfile"; }
err() {  echo -e "✖ $*" >>"$logfile"; }

wipe_one() { wipe -f -q -Q 1 -- "$1" 2>>"$logfile" || rm -f -- "$1" 2>>"$logfile"; }
wipe_file(){ wipe_one "$1" && log "✓ файл: $1" || err "файл: $1"; }

wipe_dir_contents(){                # stdout → кол‑во удалённых, stderr → progress
  local d=$1 removed=0
  mapfile -d '' items < <(find "$d" -mindepth 1 -print0 2>/dev/null || true)
  local total=${#items[@]} i=0
  for p in "${items[@]}"; do
    ((i++)); printf "\r${YELLOW}%s${NC} %d/%d" "$d" "$i" "$total" >&2
    if [[ -f $p || -L $p ]]; then wipe_file "$p" && ((removed++))
    else rm -rf -- "$p" 2>>"$logfile" && log "✓ каталог: $p" || err "каталог: $p"; fi
  done
  ((total)) && echo >&2
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

###############################################################################
# 2. основная очистка
###############################################################################
run_clean(){
  logfile="$REPORT_DIR/report_$(date '+%F-%H-%M-%S').log"; : >"$logfile"
  [[ ${#MAP_FILES[@]} -eq 0 ]] && load_lists      # ← подгружаем только если пусто
  local removed=0

  for p in "${MAP_FILES[@]}"; do
    if deny_match "$p"; then log "⚠️  deny: $p"; continue; fi
    echo -e "${GREEN}--- $p ---${NC}"
    if [[ -f $p || -L $p ]]; then
      wipe_file "$p" && ((removed++))
    elif [[ -d $p ]]; then
      before=$(find "$p" ! -type d | wc -l); echo "до: $before"
      n=$(wipe_dir_contents "$p"); ((removed+=n))
      after=$(find "$p" ! -type d | wc -l); echo "после: $after"
    else
      err "не найдено: $p"
    fi
  done

  log "Всего удалено: $removed"
  echo "$logfile"
}

###############################################################################
# 3. починка структуры корзин
###############################################################################
repair_trash_dirs(){
  load_lists; local fixed=0
  for p in "${MAP_FILES[@]}"; do
    [[ $p != */Trash/files ]] && continue
    info="${p%/files}/info"
    for d in "$p" "$info"; do
      [[ -d $d ]] || { mkdir -p -- "$d" && chmod 700 -- "$d"; echo "Создано: $d"; ((fixed++)); }
    done
  done
  ((fixed)) && echo "Исправлено: $fixed" || echo "Все корзины целы."
}

ensure_wipe
