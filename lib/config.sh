#!/bin/bash                                                                                                                                                                                                                                                             #!/bin/bash
# lib/config.sh - Interactive configuration functions

# Main configuration setup
setup_interactive_config() {
  echo "Setting up interactive configuration..."

  install_tui_tools

  get_hostname
  get_username
  get_user_password
  get_root_password
  get_luks_password
  get_timezone
  select_target_disk

  echo "Configuration complete:"
  echo "  Hostname: $HOSTNAME"
  echo "  Username: $USERNAME"
  echo " Timezone: $TIMEZONE"
  echo "  Target disk: $DISK"
}

# Hostname input with validation
get_hostname() {
  while true; do
    if command -v gum &> /dev/null; then
      HOSTNAME=$(gum input --placeholder "(e.g. archdesktop)" --prompt "Enter hostname: ")
    elif command -v dialog &> /dev/null; then
      HOSTNAME=$(dialog --title "System Configuration" --inputbox "Enter hostname:" 8 40 3>&1 1>&2 2>&3)
    else
      # shellcheck disable=SC2162
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
      USERNAME=$(gum input --placeholder "(e.g. archuser: lowercase, numbers, underscore, hyphen)" --prompt "Enter username: ")
    elif command -v dialog &> /dev/null; then
      USERNAME=$(dialog --title "User Configuration" --inputbox "Enter username:" 8 40 3>&1 1>&2 2>&3)
    else
      # shellcheck disable=SC2162
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
      USER_PASSWORD=$(gum input --password --placeholder "(minimum 6 characters)" --prompt "Enter user password: ")
      # shellcheck disable=SC2155
      local confirm_password=$(gum input --password --prompt "Confirm user password: ")
    elif command -v dialog &> /dev/null; then
      USER_PASSWORD=$(dialog --title "User Configuration" --passwordbox "Enter user password:" 8 40 3>&1 1>&2 2>&3)
      # shellcheck disable=SC2155
      local confirm_password=$(dialog --title "User Configuration" --passwordbox "Confirm password:" 8 40 3>&1 1>&2 2>&3)
    else
      # shellcheck disable=SC2162
      read -s -p "Enter user password: " USER_PASSWORD
      echo
      # shellcheck disable=SC2162
      read -s -p "Confirm password: " confirm_password
      echo
    fi

    if [[ "$USER_PASSWORD" == "$confirm_password" ]] && [[ ${#USER_PASSWORD} -ge 6 ]]; then
      break
    else
      if command -v gum &> /dev/null; then
          gum style --foreground 196 "❌ Passwords don't match or too short."
      else
          echo "Passwords don't match or too short."
      fi
    fi
  done
}

# Root password input with confirmation
get_root_password() {
  while true; do
    if command -v gum &> /dev/null; then
      ROOT_PASSWORD=$(gum input --password --placeholder "(minimum 6 characters)" --prompt "Enter secure root password: ")
      # shellcheck disable=SC2155
      local confirm_root_password=$(gum input --password --prompt "Confirm root password: ")
    elif command -v dialog &> /dev/null; then
      ROOT_PASSWORD=$(dialog --title "User Configuration" --passwordbox "Enter secure root password:" 8 40 3>&1 1>&2 2>&3)
      # shellcheck disable=SC2155
      local confirm_root_password=$(dialog --title "Root Configuration" --passwordbox "Confirm root password:" 8 40 3>&1 1>&2 2>&3)
    else
      # shellcheck disable=SC2162
      read -s -p "Enter secure root password: " ROOT_PASSWORD
      echo
      # shellcheck disable=SC2162
      read -s -p "Confirm root password: " confirm_root_password
      echo
    fi

    if [[ "$ROOT_PASSWORD" == "$confirm_root_password" ]] && [[ ${#ROOT_PASSWORD} -ge 6 ]]; then
      break
    else
      if command -v gum &> /dev/null; then
          gum style --foreground 196 "❌ Root passwords don't match or too short."
      else
          echo "Root passwords don't match or too short."
      fi
    fi
  done
}

# LUKS password input with confirmation
get_luks_password() {
  while true; do
    if command -v gum &> /dev/null; then
      LUKS_PASSWORD=$(gum input --password --placeholder "(minimum 8 characters)" --prompt "Enter LUKS encryption password: ")
      # shellcheck disable=SC2155
      local confirm_password=$(gum input --password --prompt "Confirm LUKS encryption password: ")
    elif command -v dialog &> /dev/null; then
      LUKS_PASSWORD=$(dialog --title "Disk Encryption" --passwordbox "Enter LUKS encryption password:" 8 40 3>&1 1>&2 2>&3)
      # shellcheck disable=SC2155
      local confirm_password=$(dialog --title "Disk Encryption" --passwordbox "Confirm LUKS password:" 8 40 3>&1 1>&2 2>&3)
    else
      # shellcheck disable=SC2162
      read -s -p "Enter LUKS encryption password: " LUKS_PASSWORD
      # shellcheck disable=SC2162
      read -s -p "Confirm LUKS password: " confirm_password
    fi

    if [[ "$LUKS_PASSWORD" == "$confirm_password" ]] && [[ ${#LUKS_PASSWORD} -ge 8 ]]; then
      break
    else
      if command -v gum &> /dev/null; then
          gum style --foreground 196 "❌ Passwords don't match or too short."
      else
          echo "Passwords don't match or too short."
      fi
    fi
  done
}

# Timezone selection
get_timezone() {
  # Common timezone options
  local timezones=(
    "Europe/London"
    "Europe/Stockholm"
    "Europe/Berlin"
    "Europe/Paris"
    "America/New_York"
    "America/Los_Angeles"
    "America/Chicago"
    "Asia/Tokyo"
    "Asia/Shanghai"
    "Australia/Sydney"
    "Custom"
  )

  if command -v gum &> /dev/null; then
    TIMEZONE=$(printf '%s\n' "${timezones[@]}" | gum choose --no-limit --header "Select timezone: ")
    if [[ "$TIMEZONE" == "Custom" ]]; then
      TIMEZONE=$(gum input --placeholder "(e.g. Europe/Stockholm, America/Los_Angeles, etc.)" --prompt "Enter timezone: ")
    fi
  elif command -v dialog &> /dev/null; then
    local dialog_options=()
    for i in "${!timezones[@]}"; do
      dialog_options+=("$((i+1))" "${timezones[$i]}")
    done

    # shellcheck disable=SC2155
    local selection=$(dialog --title "Timezone Selection" \
      --menu "Select timezone:" 15 50 10 \
      "${dialog_options[@]}" \
      3>&1 1>&2 2>&3)

    # shellcheck disable=SC2181
    if [[ $? -eq 0 ]]; then
      TIMEZONE="${timezones[$((selection-1))]}"
      if [[ "$TIMEZONE" == "Custom" ]]; then
          TIMEZONE=$(dialog --title "Custom Timezone" --inputbox "Enter timezone:" 8 40 3>&1 1>&2 2>&3)
      fi
    else
      TIMEZONE="Europe/London"
    fi
  else
    echo "Available timezones:"
    for i in "${!timezones[@]}"; do
      echo "$((i+1))) ${timezones[$i]}"
    done

    while true; do
      # shellcheck disable=SC2162
      read -r -p "Select timezone number (1-${#timezones[@]}): " selection
      if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#timezones[@]} ]]; then
        TIMEZONE="${timezones[$((selection-1))]}"
        if [[ "$TIMEZONE" == "Custom" ]]; then
          # shellcheck disable=SC2162
          read -r -p "Enter custom timezone: " TIMEZONE
        fi
        break
      else
        echo "Invalid selection. Please choose 1-${#timezones[@]}"
      fi
    done
  fi

  # Validate timezone exists
  if [[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
    echo "Timezone $TIMEZONE not found, defaulting to Europe/Stockholm"
    TIMEZONE="Europe/Stockholm"
  fi
}

# Disk selection with detailed information
select_target_disk() {
  local disk_list=()
  local disk_display=()

  # Collect available disks
  while IFS= read -r line; do
    # shellcheck disable=SC2155
    local name=$(echo "$line" | awk '{print $1}')
    # shellcheck disable=SC2155
    local size=$(echo "$line" | awk '{print $4}')
    # shellcheck disable=SC2155
    local type=$(echo "$line" | awk '{print $6}')

    if [[ "$type" == "disk" ]]; then
      # shellcheck disable=SC2155
      local model=$(lsblk -dno MODEL "/dev/$name" 2>/dev/null | head -1 | xargs)
      disk_list+=("/dev/$name")
      disk_display+=("$name" "$size ${model:-Unknown Model}")
    fi
  done < <(lsblk -rno NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT)

  if [[ ${#disk_list[@]} -eq 0 ]]; then
    echo "No suitable disks found!"
  fi

  # Modern selection with fzf
  if command -v fzf &> /dev/null; then
    local selection=""
    for i in "${!disk_list[@]}"; do
      selection+="${disk_list[$i]} (${disk_display[$((i*2+1))]})\n"
    done

    DISK=$(echo -e "$selection" | fzf --prompt="Select installation disk: " --height 40% | awk '{print $1}')

  # Dialog fallback
  elif command -v dialog &> /dev/null; then
    # shellcheck disable=SC2155
    local selected=$(dialog --title "Disk Selection" \
      --menu "Select installation disk:" 15 70 8 \
      "${disk_display[@]}" \
      3>&1 1>&2 2>&3)
    # shellcheck disable=SC2181
    if [[ $? -eq 0 ]]; then
      DISK="/dev/$selected"
    else
      echo "No disk selected"
    fi

  # Basic fallback
  else
    echo "Available disks:"
    for i in "${!disk_list[@]}"; do
      echo "$((i+1))) ${disk_list[$i]} - ${disk_display[$((i*2+1))]}"
    done

    while true; do
      # shellcheck disable=SC2162
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
    echo "Invalid disk selection: $DISK"
  fi
}