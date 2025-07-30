#!/usr/bin/env bash
# clean_trash – движок
# 5.0.1 — 30 Jul 2025

set -euo pipefail; IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

deny_match(){ local p=$1; [[ -f $CONF_DENY && $(grep -Fx "$p" "$CONF_DENY") ]] || [[ $p == / || $p == /home || $p == /root ]]; }

# ---------- лог (только в файл, не stdout) ---------------------------------
logfile=""                    # задаётся в run_clean
log(){   echo -e "$*"            >>"$logfile"; }
log_e(){ echo -e "✖ $*"          >>"$logfile"; }

wipe_file(){
  local f=$1
  if rm -f -- "$f" 2>>"$logfile"; then
     log "✓ файл: $f"
     return 0
  else
     log_e "файл: $f"
     return 1
  fi
}

wipe_dir_contents(){
  local d=$1 ok=0
  mapfile -d '' items < <(find "$d" -mindepth 1 -print0 2>/dev/null)
  for p in "${items[@]}"; do
    if [[ -f $p || -L $p ]]; then
      wipe_file "$p" && ((ok++))
    else
      if rm -rf -- "$p" 2>>"$logfile"; then
         log "✓ каталог: $p"
      else
         log_e "каталог: $p"
      fi
    fi
  done
  echo "$ok"
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
  logfile="$REPORT_DIR/report_$stamp.log"
  : >"$logfile"

  load_lists
  local removed=0

  for p in "${MAP_FILES[@]}"; do
    if deny_match "$p"; then
      log "⚠️  deny: $p"
      continue
    fi
    if [[ -f $p || -L $p ]]; then
      wipe_file "$p" && ((removed++))
    elif [[ -d $p ]]; then
      n=$(wipe_dir_contents "$p"); ((removed+=n))
    else
      log_e "не найдено: $p"
    fi
  done

  echo "Всего удалено: $removed" >>"$logfile"
  echo "$logfile"
}

# ---------- ремонт структуры корзин ----------------------------------------
repair_trash_dirs(){
  load_lists
  local fixed=0
  for p in "${MAP_FILES[@]}"; do
    # интересует только trash/*/files  (info = path/../info)
    [[ $p != */Trash/files ]] && continue
    info="${p%/files}/info"
    for d in "$p" "$info"; do
      if [[ ! -d $d ]]; then
        mkdir -p -- "$d" && chmod 700 -- "$d"
        echo "Создано: $d"
        ((fixed++))
      fi
    done
  done
  ((fixed)) && echo "Исправлено директорий: $fixed" || echo "Все корзины целы."
}
