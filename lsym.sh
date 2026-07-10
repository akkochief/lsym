#!/usr/bin/env bash
set -uo pipefail

APP_NAME="LSYM - Linux System Management Center"
APP_VERSION="3.0"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${BASE_DIR}/modules"
CONFIG_FILE="${BASE_DIR}/config.conf"
LOG_FILE="/tmp/lsym.log"
TMP_FILE="$(mktemp)"
DIALOG_BIN=""
BACKTITLE="${APP_NAME} v${APP_VERSION} | $(hostname) | $(date '+%Y-%m-%d %H:%M')"
HEIGHT=24
WIDTH=80
MENU_HEIGHT=14

trap 'rm -f "$TMP_FILE"' EXIT

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        cat > "$CONFIG_FILE" <<EOF
# LSYM Configuration
LOG_LEVEL="INFO"
ENABLE_COLORS="yes"
DEFAULT_EDITOR="nano"
BACKUP_PATH="/var/backups/lsym"
TEMP_CLEAN_DAYS=7
AUTO_UPDATE="no"
NOTIFICATION_EMAIL="admin@localhost"
EOF
    fi
}

log() {
    local level="${2:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $1" >> "$LOG_FILE"
}

check_dialog() {
    if command -v dialog &>/dev/null; then
        DIALOG_BIN="dialog"
    elif command -v whiptail &>/dev/null; then
        DIALOG_BIN="whiptail"
    else
        echo "dialog or whiptail not found. Installing dialog..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y dialog
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y dialog
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm dialog
        elif command -v zypper &>/dev/null; then
            sudo zypper install -y dialog
        else
            echo "ERROR: Package manager not recognized. Please install dialog manually."
            exit 1
        fi
        DIALOG_BIN="dialog"
    fi
}

d() {
    "$DIALOG_BIN" --backtitle "$BACKTITLE" "$@"
}

show_text() {
    local title="$1"
    local file="$2"
    d --title "$title" --textbox "$file" $HEIGHT $WIDTH
}

show_msg() {
    local title="$1"
    local msg="$2"
    d --title "$title" --msgbox "\n$msg" 10 65
}

ask_yesno() {
    local msg="$1"
    d --title "Confirmation" --yesno "\n$msg" 10 65
}

run_cmd() {
    local title="$1"
    local cmd="$2"
    eval "$cmd" > "$TMP_FILE" 2>&1
    show_text "$title" "$TMP_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        show_msg "Root Required" "This operation requires root privileges.\nYou will be prompted for sudo password."
        return 1
    fi
    return 0
}

sudo_cmd() {
    local cmd="$1"
    sudo bash -c "$cmd" 2>/dev/null
}

load_module() {
    local module="$1"
    local module_file="${MODULES_DIR}/${module}.sh"
    
    if [[ -f "$module_file" ]]; then
        source "$module_file"
        log "Module loaded: $module"
        return 0
    else
        show_msg "Error" "Module not found: $module\n\nPlease check that ${module}.sh exists in ${MODULES_DIR}"
        log "Module not found: $module" "ERROR"
        return 1
    fi
}

get_input() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local input=""
    
    if [[ -n "$default" ]]; then
        input=$(d --title "$title" --inputbox "\n$prompt" 10 65 "$default" 3>&1 1>&2 2>&3)
    else
        input=$(d --title "$title" --inputbox "\n$prompt" 10 65 3>&1 1>&2 2>&3)
    fi
    
    echo "$input"
}

get_password() {
    local title="$1"
    local prompt="$2"
    d --title "$title" --passwordbox "\n$prompt" 10 65 3>&1 1>&2 2>&3
}

show_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    d --clear --title "$title" --menu "\n$prompt" $HEIGHT $WIDTH $MENU_HEIGHT "$@"
}

main_menu() {
    while true; do
        local choice=$(show_menu "MAIN MENU" "Welcome to LSYM - Select a module:" \
            1 "System Information" \
            2 "Disk Management (diskpart+++)" \
            3 "Network Management" \
            4 "User & Group Management" \
            5 "Service & Process Management" \
            6 "Package Management" \
            7 "Security & Firewall" \
            8 "Backup & Maintenance" \
            9 "System Monitoring & Alerts" \
            0 "Exit" \
            3>&1 1>&2 2>&3)
        
        if [[ $? -ne 0 ]] || [[ "$choice" == "0" ]]; then
            log "User exited from main menu"
            break
        fi
        
        case "$choice" in
            1) load_module "system" && system_menu ;;
            2) load_module "disk" && disk_menu ;;
            3) load_module "network" && network_menu ;;
            4) load_module "user" && user_menu ;;
            5) load_module "service" && service_menu ;;
            6) load_module "package" && package_menu ;;
            7) load_module "security" && security_menu ;;
            8) load_module "backup" && backup_menu ;;
            9) load_module "monitor" && monitor_menu ;;
            *) show_msg "Error" "Invalid selection!" ;;
        esac
    done
}

initialize() {
    clear
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║   LSYM - LINUX SYSTEM MANAGEMENT CENTER v3.0                             ║"
    echo "║   Ultimate System Administration Tool                                   ║"
    echo "║                                                                          ║"
    echo "║   Loading...                                                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    
    mkdir -p "$MODULES_DIR"
    load_config
    check_dialog
    log "LSYM started"
    
    if [[ $EUID -ne 0 ]]; then
        show_msg "Information" "Some operations require root privileges.\nYou will be prompted for sudo password when needed."
    fi
}

cleanup() {
    rm -f "$TMP_FILE"
    log "LSYM shutdown"
    clear
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║   LSYM has been closed. Goodbye!                                       ║"
    echo "║                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

initialize
main_menu
cleanup
exit 0