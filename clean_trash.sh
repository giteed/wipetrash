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
  
  # Удаление файлов (без вывода в арифметический контекст)
  echo -e "${YELLOW}Удаление файлов в: $dir${NC}" >&2
  while IFS= read -r -d $'\0' file; do
    if wipe_one "$file"; then
      removed_files=$((removed_files + 1))
    fi
  done < <(find "$dir" -type f -print0 2>/dev/null)

  # Удаление пустых подпапок
  echo -e "${YELLOW}Поиск пустых подпапок в: $dir${NC}" >&2
  while IFS= read -r -d $'\0' subdir; do
    if [[ "$subdir" != "$dir" ]]; then
      random_name="del_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)"
      new_path="$(dirname "$subdir")/$random_name"
      
      if mv "$subdir" "$new_path" 2>/dev/null; then
        if rm -rf "$new_path" 2>/dev/null; then
          echo -e "${GREEN}Удалено: $subdir${NC}" >&2
          removed_dirs=$((removed_dirs + 1))
        else
          echo -e "${RED}Ошибка удаления: $new_path${NC}" >&2
        fi
      else
        echo -e "${RED}Ошибка переименования: $subdir${NC}" >&2
      fi
    fi
  done < <(find "$dir" -type d -empty -print0 2>/dev/null | sort -rz)

  echo -e "${GREEN}Удалено файлов: $removed_files, папок: $removed_dirs${NC}" >&2
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
