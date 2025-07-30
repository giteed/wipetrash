#!/usr/bin/env bash
# wipe_trash – меню очистки
# 2.1.0 — 29 Jul 2025

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_MSG="$("$SCRIPT_DIR/setup_wt.sh")"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/clean_trash.sh"
load_config

human() { local s=$1 u=(B K M G T); for x in "${u[@]}"; do ((s<1024))&&{ printf "%d%s" "$s" "$x"; return; }; s=$((s/1024)); done; printf "%dP" "$s"; }
scan()  { [[ -d $1 ]] || { echo "0|0"; return; }; local c b; c=$(find "$1" ! -type d -print 2>/dev/null | wc -l); b=$(du -sb "$1" 2>/dev/null | cut -f1); echo "$c|$b"; }

show_state() {
  echo "$SETUP_MSG"
  echo "──────────────────────────────────────────────"
  echo "  Состояние корзин:"
  for i in "${!LABELS[@]}"; do
    IFS='|' read -r c b <<<"$(scan "${FILES_DIRS[i]}")"
    printf "  %2d) %-38s — %s, %s\n" $((i+2)) "${LABELS[i]}" "$c объектов" "$(human "$b")"
  done
  echo "──────────────────────────────────────────────"
}

repair() {
  local changed=0
  for i in "${!LABELS[@]}"; do
    f="${FILES_DIRS[i]}"; info="${INFO_DIRS[i]}"
    if [[ -d $f && -d $info ]]; then
      echo "✔ ${LABELS[i]} — ок."
    else
      echo "✖ ${LABELS[i]} — повреждена."
      read -rp "  Создать недостающие каталоги? [y/N] " ans
      if [[ ${ans,,} == y ]]; then
        mkdir -p -- "$f" "$info" && chmod 700 -- "$f" "$info"
        echo "  → исправлено."; changed=1
      fi
    fi
  done
  ((changed)) || echo "Все корзины исправны."
  read -rp "Enter …"
}

help() { cat <<EOF

 wipe_trash – безвозвратная очистка корзин (.Trash-UID) и списка «Недавние файлы».

 ▸ Удаление проходит через wipe (если установлен) либо rm.
 ▸ Пункт «r» чинит структуру корзин.
 ▸ Пункт «a» добавляет в список свои каталоги для очистки.

EOF
read -rp "Enter …"; }

ADD_SCRIPT="$SCRIPT_DIR/add_safe_dir.sh"

while true; do
  clear
  echo "===========  W I P E   T R A S H  ==========="
  show_state
  echo "  1) Очистить ВСЁ (все корзины + history)"
  for i in "${!LABELS[@]}"; do printf " %2d) Очистить: %s\n" $((i+2)) "${LABELS[i]}"; done
  RECENT=$(( ${#LABELS[@]} + 2 ))
  printf "\n %2d) Только history «Недавние файлы»\n" $RECENT
  echo "  a) Добавить каталоги для очистки"
  echo "  r) Проверить/починить структуру"
  echo "  h) Help"
  echo "  q) Quit"
  read -rp $'\n'"Выберите действие [Enter = 1]: " choice
  choice=${choice:-1}

  BEFORE=(); SIZE=()
  for d in "${FILES_DIRS[@]}"; do IFS='|' read -r c b <<<"$(scan "$d")"; BEFORE+=("$c"); SIZE+=("$b"); done

  case $choice in
    1) auto_mode ;;
    $RECENT) clean_history ;;
    a|A) "$ADD_SCRIPT"; load_config; continue ;;         # перечитываем конфиг
    r|R) repair; continue ;;
    h|H) help; continue ;;
    q|Q) echo "Выход…"; exit 0 ;;
    ''|*[!0-9]*) echo "Неверный ввод!"; read -rp "Enter …"; continue ;;
    *)
      idx=$((choice-2))
      if (( idx>=0 && idx<${#LABELS[@]} )); then
        clean_trash "${FILES_DIRS[idx]}" "${INFO_DIRS[idx]}"
      else
        echo "Неверный пункт!"; read -rp "Enter …"; continue
      fi ;;
  esac

  echo "──────────────────────────────────────────────"
  echo "  Отчёт:"
  total_c=0; total_b=0
  for i in "${!LABELS[@]}"; do
    IFS='|' read -r ac ab <<<"$(scan "${FILES_DIRS[i]}")"
    dc=$(( BEFORE[i]-ac )); db=$(( SIZE[i]-ab ))
    ((dc<=0)) && continue
    total_c=$((total_c+dc)); total_b=$((total_b+db))
    printf "  • %-38s — %s объектов (%s)\n" "${LABELS[i]}" "$dc" "$(human "$db")"
  done
  (( total_c )) && echo "  Итого: ~$total_c объектов, $(human "$total_b") удалено." \
                 || echo "  Нечего было удалять."
  echo "──────────────────────────────────────────────"
  read -rp "Enter …"
done
