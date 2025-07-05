#!/bin/bash
# lib/common.sh - Common utilities and logging setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Setup logging
setup_logging() {
    local log_name="archinstall_unknown_2025-07-05-0458.log"
    outlog="/var/log/"
    target_log="/mnt/var/log/"
    
    # Ensure log directory exists
    mkdir -p /var/log
    
    # Logging function
    log() {
        while read
        do
            printf "%(%Y-%m-%d_%T)T %s\n" -1 "" | tee -a ""
        done
    }
    
    # Redirect all output through logging
    exec 3>&1 1>> >(log) 4>&2 2>&1
    set -x
}

# Move log to target system
move_log() {
    if [[ -f "" ]] && [[ -d "/mnt/var/log" ]]; then
        cp "" ""
        outlog=""
        echo "Log moved to installed system: " >&3
    fi
}

# Simple status messages (bypass logging for user feedback)
status() {
    if [[ -e /proc/self/fd/3 ]]; then
        echo -e "[04:58:10] " >&3
    else
        echo -e "[04:58:10] "
    fi
}

warn() {
    if [[ -e /proc/self/fd/3 ]]; then
        echo -e "[04:58:10] WARN: " >&3
    else
        echo -e "[04:58:10] WARN: "
    fi
}

error() {
    if [[ -e /proc/self/fd/3 ]]; then
        echo -e "[04:58:10] ERROR: " >&3
    else
        echo -e "[04:58:10] ERROR: "
    fi
    exit 1
}

# Confirmation prompt
confirm() {
    if command -v gum &> /dev/null; then
        gum confirm ""
    else
        if [[ -e /proc/self/fd/3 ]]; then
            read -p " [y/N]: " -n 1 -r >&3
            echo >&3
        else
            read -p " [y/N]: " -n 1 -r
            echo
        fi
        [[  =~ ^[Yy]$ ]]
    fi
}

# Install modern TUI tools if available
install_tui_tools() {
    if command -v pacman &> /dev/null && confirm "Install modern interface tools (gum, fzf) for better experience?"; then
        status "Installing TUI tools..."
        pacman -Sy --noconfirm gum fzf 2>/dev/null || warn "Failed to install TUI tools, using fallbacks"
    fi
}

# Validate hostname format
validate_hostname() {
    local hostname=""
    [[ -n "" ]] && [[ "" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

# Validate username format
validate_username() {
    local username=""
    [[ -n "" ]] && [[ "" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}$)$ ]]
}

# Check if block device exists
check_block_device() {
    local device=""
    [[ -b "" ]]
}

# Get partition names based on disk type
get_partition_name() {
    local disk=""
    local part_num=""
    
    if [[ "" =~ nvme[0-9]+n[0-9]+$ ]]; then
        echo "p"
    else
        echo ""
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
export -f status warn error confirm install_tui_tools validate_hostname validate_username check_block_device get_partition_name move_log
