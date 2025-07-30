#!/usr/bin/env bash
# clean_trash – движок (с прогрессом и wipe)
# 5.1.0 — 30 Jul 2025

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"
mkdir -p "$REPORT_DIR"

have_wipe(){ command -v wipe &>/dev/null; }

deny_match(){
  local p=$1
  [[ -f $CONF_DENY && $(grep -Fx "$p" "$CONF_DENY" 2>/dev/null) ]] && return 0
  [[ $p == / || $p == /home || $p == /root ]] && return 0
  return 1
}

logfile=""
log(){ echo -e "$*" >>"$logfile"; }
err(){ echo -e "✖ $*" >>"$logfile"; }

progress(){
  local msg=$1 cur=$2 total=$3
  printf "\r${YELLOW}%s ${GREEN}%d/%d${NC}" "$msg" "$cur" "$total"
}

wipe_one(){
  local path=$1
  if have_wipe; then
    wipe -f -q -Q 1 -- "$path" 2>>"$logfile" || rm -f -- "$path" 2>>"$logfile"
  else
    rm -f -- "$path" 2>>"$logfile"
  fi
}

wipe_file(){
  local f=$1
  if wipe_one "$f"; then
    log "✓ файл: $f"; return 0
  else
    err "файл: $f"; return 1
  fi
}

wipe_dir_contents(){
  local d=$1 removed=0
  mapfile -d '' items < <(find "$d" -mindepth 1 -print0 2>/dev/null || true)
  local total=${#items[@]} i=0
  for p in "${items[@]}"; do
    ((i++)); progress "…$d" "$i" "$total"
    if [[ -f $p || -L $p ]]; then
      wipe_file "$p" && ((removed++))
    else
      if rm -rf -- "$p" 2>>"$logfile"; then
        log "✓ каталог: $p"
      else
        err "каталог: $p"
      fi
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
  logfile="$REPORT_DIR/report_$stamp.log"
  : >"$logfile"

  load_lists
  local removed=0

  for p in "${MAP_FILES[@]}"; do
    if deny_match "$p"; then
      log "⚠️  deny: $p"
      continue
    fi

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
  load_lists
  local fixed=0
  for p in "${MAP_FILES[@]}"; do
    [[ $p != */Trash/files ]] && continue
    info="${p%/files}/info"
    for d in "$p" "$info"; do
      if [[ ! -d $d ]]; then
        mkdir -p -- "$d" && chmod 700 -- "$d"
        echo "Создано: $d"; ((fixed++))
      fi
    done
  done
  ((fixed)) && echo "Исправлено директорий: $fixed" || echo "Все корзины целы."
}
