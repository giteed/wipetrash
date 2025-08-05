#!/usr/bin/env bash
# browser_paths_erase.sh – Part 1: Setup and launch browser cache erasure
# Оптимизированная версия с сохранением всей функциональности
set -euo pipefail
IFS=$'\n\t'

# ──── Конфигурация ────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/browser_cache.conf"
BROWSER_SCAN_SCRIPT="$SCRIPT_DIR/browser_paths.sh"
BROWSER_ERASE_SCRIPT_2="$SCRIPT_DIR/browser_paths_erase_2.sh"

# ──── Инициализация ────
EXECUTE=0; DEBUG=0; AUTO_GENERATE=1

# ──── Функции ────
show_help() {
    cat <<-EOF
	Usage: ${0##*/} [OPTIONS]
	Setup and launch browser cache erasure based on browser_cache.conf.

	OPTIONS:
	    -h, --help              Show this help
	    -x, --execute           Perform real deletion (default: dry-run)
	    -n, --no-auto-generate  Disable auto config generation
	    -d, --debug             Enable debug output
	EOF
    exit 0
}

die() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
dbg() { (( DEBUG )) && echo -e "${BLUE}[debug]${NC} $*" >&2; }

generate_config() {
    echo -e "${YELLOW}Generating config...${NC}"
    [[ -x "$BROWSER_SCAN_SCRIPT" ]] || die "Scanner script not executable"
    
    if "$BROWSER_SCAN_SCRIPT" --force $([[ $DEBUG -eq 1 ]] && echo "--debug"); then
        [[ -s "$CONF" ]] || die "Generated config is empty"
        echo -e "${GREEN}Config generated successfully.${NC}"
    else
        die "Config generation failed (exit code $?)"
    fi
}

# ──── Основной код ────
(( BASH_VERSINFO[0] < 4 )) && die "Requires Bash 4.0+"
[[ $EUID -eq 0 ]] && die "Do not run as root"
[[ ! -x "$BROWSER_ERASE_SCRIPT_2" ]] && die "Missing part 2 script"

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -x|--execute) EXECUTE=1 ;;
        -n|--no-auto-generate) AUTO_GENERATE=0 ;;
        -d|--debug) DEBUG=1 ;;
        --no-color) : ;; # Игнорируем
        -*) die "Unknown option: $1" ;;
        *) die "Unexpected argument: $1" ;;
    esac
    shift
done

# Проверка и генерация конфига
if [[ ! -f "$CONF" || ! -s "$CONF" ]]; then
    if (( AUTO_GENERATE )); then
        generate_config || exit 1
    else
        die "Config missing/empty (use --no-auto-generate to disable auto-creation)"
    fi
fi

# Подготовка и запуск
args_to_pass=()
(( EXECUTE )) && args_to_pass+=(--execute)
(( DEBUG )) && args_to_pass+=(--debug)

dbg "Launching: $BROWSER_ERASE_SCRIPT_2 ${args_to_pass[*]}"
echo -e "${GREEN}Starting in ${EXECUTE:+REAL DELETE/:dry-run} mode...${NC}"

"$BROWSER_ERASE_SCRIPT_2" "${args_to_pass[@]}"

dbg "Processing completed"
echo -e "${GREEN}Operation finished.${NC}"
