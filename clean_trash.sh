#!/usr/bin/env bash
# clean_trash – движок (wipe + rm‑fallback по запросу)
# 5.4.2 — 30 Jul 2025

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"; mkdir -p "$REPORT_DIR"

WIPE_PASSES="${WIPE_PASSES:-1}"
USE_RM_FALLBACK="${USE_RM_FALLBACK:-0}"

# ── ensure_wipe (НЕ вызываем здесь!) ───────────────────────────────────────
ensure_wipe() {
  local w
  if w=$(command -v wipe); then
      echo -e "${GREEN}✓ wipe: $w${NC}"
      (( USE_RM_FALLBACK )) && echo -e "${YELLOW}rm‑fallback = ON${NC}"
      return
  fi
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

ask_fallback(){
  (( USE_RM_FALLBACK )) && return
  read -rp $'\n'"wipe не смог удалить файл. Включить запасной rm? [y/N] " a
  if [[ ${a,,} == y ]]; then
      USE_RM_FALLBACK=1
      export USE_RM_FALLBACK
      echo -e "${YELLOW}rm‑fallback включён.${NC}"
  fi
}

wipe_one(){                       # $1 = файл
  local opts=( -f -q -Q "$WIPE_PASSES" )
  if wipe "${opts[@]}" -- "$1" >>"$logfile" 2>&1; then
      log "wipe файл: $1"
  else
      err "wipe‑error: $1"
      ask_fallback
      if (( USE_RM_FALLBACK )); then
          rm -f -- "$1" 2>>"$logfile" && log "rm файл: $1" || err "rm‑error: $1"
      fi
  fi
}

wipe_dir_contents(){              # stdout → удалённых, stderr → progress
  local d=$1 removed=0
  mapfile -d '' files < <(find "$d" -type f -print0 2>/dev/null || true)
  local total=${#files[@]} i=0
  for f in "${files[@]}"; do
    ((i++)); printf "\r${YELLOW}%s${NC} %d/%d" "$d" "$i" "$total" >&2
    wipe_one "$f" && ((removed++))
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
      wipe_one "$p"; ((removed++))
    elif [[ -d $p ]]; then
      before=$(find "$p" -type f | wc -l); echo "до: $before"
      n=$(wipe_dir_contents "$p"); ((removed+=n))
      after=$(find "$p" -type f | wc -l); echo "после: $after"
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
