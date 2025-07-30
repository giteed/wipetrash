#!/usr/bin/env bash
# clean_trash – движок (wipe + прогресс + отчёт)
# 5.3.0 — 30 Jul 2025

set -euo pipefail
IFS=$'\n\t'

# ── цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ── переменные ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"; mkdir -p "$REPORT_DIR"

WIPE_PASSES="${WIPE_PASSES:-1}"          # сколько проходов (1 — быстро, >1 — дольше)
WIPE_SILENT="${WIPE_SILENT:-0}"          # 1 => тихий режим

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
deny_match(){ [[ -f $CONF_DENY && $(grep -Fx "$1" "$CONF_DENY") ]] || [[ $1 == / || $1 == /home || $1 == /root ]]; }

logfile=""; log(){ echo -e "$*" >>"$logfile"; }; err(){ echo -e "✖ $*" >>"$logfile"; }

wipe_one() {          # $1 = файл
  local opt_silent=( )
  (( WIPE_SILENT )) && opt_silent+=( -q )
  wipe -f -Q "$WIPE_PASSES" "${opt_silent[@]}" -- "$1" 2>>"$logfile" \
      && log "wipe файл: $1" \
      || { rm -f -- "$1" 2>>"$logfile"; err "rm файл: $1"; }
}

wipe_file(){ wipe_one "$1"; }

wipe_dir_contents(){                # stdout → кол‑во удалённых, stderr → progress
  local d=$1 removed=0
  mapfile -d '' items < <(find "$d" -mindepth 1 -print0 2>/dev/null || true)
  local total=${#items[@]} i=0
  for p in "${items[@]}"; do
    ((i++)); printf "\r${YELLOW}%s${NC} %d/%d" "$d" "$i" "$total" >&2
    if [[ -f $p || -L $p ]]; then wipe_file "$p" && ((removed++))
    else rm -rf -- "$p" 2>>"$logfile" && log "rm каталог: $p" || err "каталог: $p"; fi
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
  [[ ${#MAP_FILES[@]} -eq 0 ]] && load_lists
  local removed=0

  for p in "${MAP_FILES[@]}"; do
    deny_match "$p" && { log "⚠️  deny: $p"; continue; }
    echo -e "${GREEN}--- $p ---${NC}"
    if [[ -f $p || -L $p ]]; then
      wipe_file "$p"; ((removed++))
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
