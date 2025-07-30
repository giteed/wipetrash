#!/usr/bin/env bash
# clean_trash – движок
# 5.0.0 — 29 Jul 2025

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then set -euo pipefail; fi
IFS=$'\n\t'

# ← цвета уже приведены выше

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"

mkdir -p "$REPORT_DIR"

# ---------- helpers ---------------------------------------------------------
human() { local s=$1 u=(B K M G T); for x in "${u[@]}"; do ((s<1024))&&{ printf "%d%s" "$s" "$x"; return; }; s=$((s/1024)); done; printf "%dP" "$s"; }

logfile=""          # будет установлен в run_clean()

log()    { echo -e "$*"            | tee -a "$logfile"; }
log_err(){ echo -e "${RED}$*${NC}" | tee -a "$logfile" >&2; }

deny_match() {
  local p=$1
  grep -Fxq "$p" "$CONF_DENY" 2>/dev/null && return 0
  # также блокируем «/» и «/home»/«/root» супера
  [[ $p == / || $p == /home || $p == /root ]] && return 0
  return 1
}

wipe_file() {
  local f=$1
  if ! rm -f -- "$f" 2>>"$logfile"; then
    log_err "  ✖ не удалось: $f"
    return 1
  fi
  log "  ✓ файл: $f"
}

wipe_dir_contents() {
  local d=$1; local n ok=0
  mapfile -d '' items < <(find "$d" -mindepth 1 -print0 2>/dev/null)
  for p in "${items[@]}"; do
    if [[ -f $p || -L $p ]]; then
      wipe_file "$p" && ((ok++))
    else
      rm -rf -- "$p" 2>>"$logfile" \
        && log "  ✓ каталог: $p" \
        || log_err "  ✖ не удалось: $p"
    fi
  done
  echo "$ok"
}

# ---------- загрузка конфигов ----------------------------------------------
load_lists() {
  MAP_FILES=()
  for cfg in "$CONF_AUTO" "$CONF_MANUAL"; do
    [[ -r $cfg ]] || continue
    while IFS='|' read -r p _; do
      [[ $p == \#* || -z $p ]] && continue
      MAP_FILES+=("$p")
    done <"$cfg"
  done
}

# ---------- основная функция очистки ---------------------------------------
run_clean() {
  local stamp=$(date '+%Y-%m-%d_%H-%M-%S')
  logfile="$REPORT_DIR/report_$stamp.log"
  touch "$logfile"

  load_lists
  local removed=0

  for p in "${MAP_FILES[@]}"; do
    if deny_match "$p"; then
      log "  ⚠️  пропущено (deny): $p"
      continue
    fi

    if [[ -f $p ]]; then
      wipe_file "$p" && ((removed++))
    elif [[ -d $p ]]; then
      n=$(wipe_dir_contents "$p"); ((removed+=n))
    else
      log_err "  ⚠️  не найдено: $p"
    fi
  done

  log "Всего удалено объектов: $removed"
  echo "$logfile"
}
