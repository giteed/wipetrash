#!/usr/bin/env bash
# clean_trash.sh - основной движок очистки
# 5.4.5 - 31 Jul 2025

source "$(dirname "${BASH_SOURCE[0]}")/wipe_functions.sh"

WIPE_PASSES="${WIPE_PASSES:-1}"
USE_RM_FALLBACK="${USE_RM_FALLBACK:-0}"

ask_fallback() {
  (( USE_RM_FALLBACK )) && return 0
  read -rp $'\n'"wipe не смог удалить файл. Включить запасной rm? [y/N] " a
  [[ ${a,,} == y ]] && { USE_RM_FALLBACK=1; export USE_RM_FALLBACK; }
}

wipe_one() {
  local file="$1"
  if wipe -f -q -Q "$WIPE_PASSES" -- "$file" >>"$logfile" 2>&1; then
    log "wipe файл: $file"
    return 0
  else
    err "wipe-error: $file"
    ask_fallback
    if (( USE_RM_FALLBACK )); then
      rm -f -- "$file" 2>>"$logfile" && log "rm файл: $file" || err "rm-error: $file"
    fi
    return 1
  fi
}

wipe_dir_contents() {
  local dir="$1"
  local removed_files=0
  local removed_dirs=0
  
  # Удаление файлов с прогресс-баром
  local files=()
  mapfile -t files < <(find "$dir" -type f -print0 2>/dev/null | xargs -0)
  local total_files=${#files[@]}
  
  echo -e "${YELLOW}Удаление файлов (0/$total_files)...${NC}" >&2
  for ((i=0; i<total_files; i++)); do
    printf "\r${YELLOW}Удаление файлов (%d/%d)...${NC}" "$((i+1))" "$total_files" >&2
    wipe_one "${files[i]}" && removed_files=$((removed_files + 1))
  done
  ((total_files > 0)) && echo >&2

  # Удаление пустых папок с прогресс-баром
  local empty_dirs=()
  mapfile -t empty_dirs < <(find "$dir" -type d -empty -print0 2>/dev/null | xargs -0)
  local total_dirs=${#empty_dirs[@]}
  
  echo -e "${YELLOW}Удаление пустых папок (0/$total_dirs)...${NC}" >&2
  for ((i=0; i<total_dirs; i++)); do
    subdir="${empty_dirs[i]}"
    [[ "$subdir" == "$dir" ]] && continue
    
    printf "\r${YELLOW}Удаление пустых папок (%d/%d)...${NC}" "$((i+1))" "$total_dirs" >&2
    random_name="del_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
    new_path="$(dirname "$subdir")/$random_name"
    
    if mv "$subdir" "$new_path" 2>/dev/null && rm -rf "$new_path" 2>/dev/null; then
      removed_dirs=$((removed_dirs + 1))
    fi
  done
  ((total_dirs > 0)) && echo >&2

  echo -e "${GREEN}Удалено: $removed_files файлов, $removed_dirs папок${NC}" >&2
  echo $((removed_files + removed_dirs))
}


run_clean() {
  logfile="$REPORT_DIR/report_$(date '+%F-%H-%M-%S').log"
  : >"$logfile"
  load_lists || return 1
  local removed_total=0

  for path in "${MAP_FILES[@]}"; do
    if deny_match "$path"; then
      log "⚠️  deny: $path"
      continue
    fi
    
    echo -e "\n${GREEN}--- $path ---${NC}" >&2
    if [[ -f "$path" || -L "$path" ]]; then
      if wipe_one "$path"; then
        removed_total=$((removed_total + 1))
      fi
    elif [[ -d "$path" ]]; then
      before=$(find "$path" -type f | wc -l)
      echo "Файлов до: $before" >&2
      n=$(wipe_dir_contents "$path")
      removed_total=$((removed_total + n))
      after=$(find "$path" -type f | wc -l)
      echo "Файлов после: $after" >&2
    else
      err "не найдено: $path"
    fi
  done

  log "Всего удалено объектов: $removed_total"
  echo "$logfile"
}


repair_trash_dirs() {
  load_lists || return 1
  local fixed=0
  for path in "${MAP_FILES[@]}"; do
    [[ "$path" != */Trash/files ]] && continue
    info_dir="${path%/files}/info"
    for dir in "$path" "$info_dir"; do
      if [[ ! -d "$dir" ]]; then
        mkdir -p -- "$dir" && chmod 700 -- "$dir"
        echo "Создано: $dir"
        ((fixed++))
      fi
    done
  done
  ((fixed)) && echo "Исправлено: $fixed" || echo "Все корзины целы."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  init_dirs
  ensure_wipe
  run_clean
fi
