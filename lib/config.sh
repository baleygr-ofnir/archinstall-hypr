                                                                                                                                                                                                                                                                #!/bin/bash
# lib/config.sh - Interactive configuration functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Main configuration setup
setup_interactive_config() {
    status "Setting up interactive configuration..."

    install_tui_tools

    get_hostname
    get_username
    get_user_password
    get_luks_password
    select_target_disk

    status "Configuration complete:"
    status "  Hostname: $HOSTNAME"
    status "  Username: $USERNAME"
    status "  Target disk: $DISK"
}

# Hostname input with validation
get_hostname() {
    while true; do
        if command -v gum &> /dev/null; then
            HOSTNAME=$(gum input --placeholder "Enter hostname (e.g., myarch)" --prompt "Hostname: ")
        elif command -v dialog &> /dev/null; then
            HOSTNAME=$(dialog --title "System Configuration" --inputbox "Enter hostname:" 8 40 3>&1 1>&2 2>&3)
        else
            read -p "Enter hostname: " HOSTNAME
        fi

        if validate_hostname "$HOSTNAME"; then
            break
        else
            if command -v gum &> /dev/null; then
                gum style --foreground 196 "❌ Invalid hostname. Use only letters, numbers, and hyphens."
            else
                echo "Invalid hostname. Use only letters, numbers, and hyphens."
            fi
        fi
    done
}

# Username input with validation
get_username() {
    while true; do
        if command -v gum &> /dev/null; then
            USERNAME=$(gum input --placeholder "Enter username" --prompt "Username: ")
        elif command -v dialog &> /dev/null; then
            USERNAME=$(dialog --title "User Configuration" --inputbox "Enter username:" 8 40 3>&1 1>&2 2>&3)
        else
            read -p "Enter username: " USERNAME
        fi

        if validate_username "$USERNAME"; then
            break
        else
            if command -v gum &> /dev/null; then
                gum style --foreground 196 "❌ Invalid username. Use lowercase letters, numbers, underscore, hyphen."
            else
                echo "Invalid username. Use lowercase letters, numbers, underscore, hyphen."
            fi
        fi
    done
}

# Password input with confirmation
get_user_password() {
    while true; do
        if command -v gum &> /dev/null; then
            USER_PASSWORD=$(gum input --password --placeholder "Enter user password")
            local confirm_password=$(gum input --password --placeholder "Confirm password")
        elif command -v dialog &> /dev/null; then
            USER_PASSWORD=$(dialog --title "User Configuration" --passwordbox "Enter user password:" 8 40 3>&1 1>&2 2>&3)
            local confirm_password=$(dialog --title "User Configuration" --passwordbox "Confirm password:" 8 40 3>&1 1>&2 2>&3)
        else
            read -s -p "Enter user password: " USER_PASSWORD
            echo
            read -s -p "Confirm password: " confirm_password
            echo
        fi

        if [[ "$USER_PASSWORD" == "$confirm_password" ]] && [[ ${#USER_PASSWORD} -ge 6 ]]; then
            break
        else
            if command -v gum &> /dev/null; then
                gum style --foreground 196 "❌ Passwords don't match or too short (min 6 chars)."
            else
                echo "Passwords don't match or too short (minimum 6 characters)."
            fi
        fi
    done
}

# LUKS password input with confirmation
get_luks_password() {
    while true; do
        if command -v gum &> /dev/null; then
            LUKS_PASSWORD=$(gum input --password --placeholder "Enter LUKS encryption password")
            local confirm_password=$(gum input --password --placeholder "Confirm LUKS password")
        elif command -v dialog &> /dev/null; then
            LUKS_PASSWORD=$(dialog --title "Disk Encryption" --passwordbox "Enter LUKS encryption password:" 8 40 3>&1 1>&2 2>&3)
            local confirm_password=$(dialog --title "Disk Encryption" --passwordbox "Confirm LUKS password:" 8 40 3>&1 1>&2 2>&3)
        else
            read -s -p "Enter LUKS encryption password: " LUKS_PASSWORD
            echo
            read -s -p "Confirm LUKS password: " confirm_password
            echo
        fi

        if [[ "$LUKS_PASSWORD" == "$confirm_password" ]] && [[ ${#LUKS_PASSWORD} -ge 8 ]]; then
            break
        else
            if command -v gum &> /dev/null; then
                gum style --foreground 196 "❌ Passwords don't match or too short (min 8 chars)."
            else
                echo "Passwords don't match or too short (minimum 8 characters)."
            fi
        fi
    done
}

# Disk selection with detailed information
select_target_disk() {
    local disk_list=()
    local disk_display=()

    # Collect available disks
    while IFS= read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $4}')
        local type=$(echo "$line" | awk '{print $6}')

        if [[ "$type" == "disk" ]]; then
            local model=$(lsblk -dno MODEL "/dev/$name" 2>/dev/null | head -1 | xargs)
            disk_list+=("/dev/$name")
            disk_display+=("$name" "$size ${model:-Unknown Model}")
        fi
    done < <(lsblk -rno NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT)

    if [[ ${#disk_list[@]} -eq 0 ]]; then
        error "No suitable disks found!"
    fi

    # Modern selection with fzf
    if command -v fzf &> /dev/null; then
        local selection=""
        for i in "${!disk_list[@]}"; do
            selection+="${disk_list[$i]} (${disk_display[$((i*2+1))]})\n"
        done

        DISK=$(echo -e "$selection" | fzf --prompt="Select installation disk: " --height 40% | awk '{print $1}')

    # Diaecho fallback
    elif command -v dialog &> /dev/null; then
        local selected=$(dialog --title "Disk Selection" \
            --menu "Select installation disk:" 15 70 8 \
            "${disk_display[@]}" \
            3>&1 1>&2 2>&3)

        if [[ $? -eq 0 ]]; then
            DISK="/dev/$selected"
        else
            error "No disk selected"
        fi

    # Basic fallback
    else
        echo "Available disks:"
        for i in "${!disk_list[@]}"; do
            echo "$((i+1))) ${disk_list[$i]} - ${disk_display[$((i*2+1))]}"
        done

        while true; do
            read -p "Select disk number: " selection
            if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#disk_list[@]} ]]; then
                DISK="${disk_list[$((selection-1))]}"
                break
            else
                echo "Invalid selection. Please choose 1-${#disk_list[@]}"
            fi
        done
    fi

    if [[ -z "$DISK" ]] || ! check_block_device "$DISK"; then
        error "Invalid disk selection: $DISK"
    fi
}
