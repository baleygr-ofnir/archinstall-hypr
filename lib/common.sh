#!/bin/bash
# lib/common.sh - Common utilities and logging setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Setup logging (without set -x)
setup_logging() {
    local log_name="archinstall_${HOSTNAME:-unknown}_$(date +"%Y-%m-%d-%H%M").log"
    outlog="/var/log/$log_name"
    target_log="/mnt/var/log/$log_name"

    # Ensure log directory exists
    mkdir -p /var/log

    # Logging function
    log() {
        while read
        do
            printf "%(%Y-%m-%d_%T)T %s\n" -1 "$REPLY" | tee -a "$outlog"
        done
    }

    # Redirect all output through logging (but don't enable set -x yet)
    exec 3>&1 1>> >(log) 4>&2 2>&1
}

# Enable command tracing (call this after interactive setup)
enable_command_tracing() {
    set -x
}

# Move log to target system
move_log() {
    if [[ -f "$outlog" ]] && [[ -d "/mnt/var/log" ]]; then
        cp "$outlog" "$target_log"
        outlog="$target_log"
        echo "Log moved to installed system: $target_log" >&3
    fi
}

# Simple status messages (bypass logging for user feedback)
status() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}" >&3 2>/dev/null || echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN: $1${NC}" >&3 2>/dev/null || echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}" >&3 2>/dev/null || echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Confirmation prompt
confirm() {
    if command -v gum &> /dev/null; then
        gum confirm "$1"
    else
        { read -p "$(echo -e "${YELLOW}" "$1" "${NC}") [y/N]: " -n 1 -r >&3 && echo >&3; } 2>/dev/null || { read -p "$(echo -e "${YELLOW}" "$1" "${NC}") [y/N]: " -n 1 -r && echo; }
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Install modern TUI tools if available
install_tui_tools() {
    if command -v pacman &> /dev/null && confirm "Install modern interface tools (gum, fzf) for better experience?"; then
        status "Installing TUI tools..."
        pacman -Sy --noconfirm gum fzf 2>/dev/null || warn "Failed to install TUI tools, using fallbacks"
    fi
}

# Hostname validation function
validate_hostname() {
    local hostname="$1"

    # Check length (1-63 characters)
    if [[ ${#hostname} -lt 1 || ${#hostname} -gt 63 ]]; then
        return 1
    fi

    # Check format: letters, numbers, hyphens (no leading/trailing hyphens)
    if [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Username validation function
validate_username() {
    local username="$1"

    # Check length (1-32 characters)
    if [[ ${#username} -lt 1 || ${#username} -gt 32 ]]; then
        return 1
    fi

    # Check format: lowercase letters, numbers, underscore, hyphen (must start with letter)
    if [[ "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Timezone validation function
validate_timezone() {
    local timezone="$1"

    # Check basic format (Continent/City)
    if [[ ! "$timezone" =~ ^[A-Za-z_]+/[A-Za-z_]+$ ]]; then
        return 1
    fi

    # Check if timezone exists in system
    if command -v timedatectl &> /dev/null; then
        timedatectl list-timezones | grep -q "^$timezone$"
        return $?
    elif [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
        return 0
    else
        # Fallback: check common timezones
        case "$timezone" in
            America/*|Europe/*|Asia/*|Africa/*|Australia/*|Pacific/*|Arctic/*|Atlantic/*|Indian/*)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

# Block device validation function
check_block_device() {
    local device="$1"

    # Check if device exists and is a block device
    if [[ -b "$device" ]]; then
        return 0
    else
        return 1
    fi
}


# Get partition names based on disk type
get_partition_name() {
    local disk="$1"
    local part_num="$2"

    if [[ "$disk" =~ nvme[0-9]+n[0-9]+$ ]]; then
        echo "${disk}p${part_num}"
    else
        echo "${disk}${part_num}"
    fi
}

# Clean exit handler
cleanup() {
    status "Cleaning up..."
    # Unmount any mounted filesystems
    umount -R /mnt 2>/dev/null || true
    # Close any open encrypted volumes
    cryptsetup close usrvol 2>/dev/null || true
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Export functions for use in sourced scripts
export -f status warn error confirm install_tui_tools validate_hostname validate_username validate_timezone check_block_device get_partition_name move_log