#!/usr/bin/env bash
# wipe_functions.sh - общие функции для всех скриптов
# 1.0.0 - 31 Jul 2025

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_AUTO="$SCRIPT_DIR/trash_auto.conf"
CONF_MANUAL="$SCRIPT_DIR/trash_manual.conf"
CONF_DENY="$SCRIPT_DIR/trash_deny.conf"
REPORT_DIR="$SCRIPT_DIR/reports"

# Инициализация директорий
mkdir -p "$REPORT_DIR" || {
  echo -e "${RED}Ошибка создания $REPORT_DIR${NC}" >&2
  exit 1
}

# Проверка утилиты wipe
ensure_wipe() {
  if ! command -v wipe &>/dev/null; then
    echo -e "${RED}✖ Ошибка: «wipe» не установлен.${NC}" >&2
    if command -v apt-get &>/dev/null; then
      read -rp "Установить «wipe» через apt-get? [Y/n] " ans
      [[ ${ans:-Y} =~ ^[Nn]$ ]] && exit 1
      sudo apt-get update && sudo apt-get install -y wipe || exit 1
    else
      echo -e "${RED}Установите «wipe» вручную!${NC}" >&2
      exit 1
    fi
  fi
  echo -e "${GREEN}✓ wipe: $(command -v wipe)${NC}"
}

# Загрузка списков из конфигов
load_lists() {
  MAP_FILES=()
  for cfg in "$CONF_AUTO" "$CONF_MANUAL"; do
    [[ -r "$cfg" ]] || continue
    while IFS='|' read -r path _; do
      [[ -z "$path" || "$path" == \#* ]] && continue
      MAP_FILES+=("$path")
    done <"$cfg"
  done
}

# Проверка запрещенных путей
deny_match() {
  [[ -f "$CONF_DENY" ]] && grep -Fxq -- "$1" "$CONF_DENY" || 
  [[ "$1" == / || "$1" == /home || "$1" == /root ]]
}

# Логирование
log() { echo -e "$*" >>"$logfile"; }
err() { echo -e "✖ $*" >>"$logfile"; }
