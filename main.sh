#!/bin/bash
# main.sh - Arch Linux Modular Btrfs Installation Script
# Main orchestrator that sources modular components

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global variables
DISK=""
HOSTNAME=""
# shellcheck disable=SC2034
LANDOMAIN=""
# shellcheck disable=SC2034
DOMAINSUFFIX=""
USERNAME=""
# shellcheck disable=SC2034
USER_PASSWORD=""
# shellcheck disable=SC2034
ROOT_PASSWORD=""
# shellcheck disable=SC2034
LUKS_PASSWORD=""
# shellcheck disable=SC2034
TIMEZONE=""
EFI_SIZE="1G"
# shellcheck disable=SC2034
SYSVOL_SIZE="65G"
# shellcheck disable=SC2034
BTRFS_OPTS="defaults,noatime,compress=zstd:3,discard=async,space_cache=v2"

# Source all modules
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/partitioning.sh"
source "${SCRIPT_DIR}/lib/install.sh"

# Main installation flow
main() {
  check_requirements
  #setup_logging
  setup_interactive_config
  confirm_installation
  #enable_command_tracing
  perform_installation
  cleanup_and_finish
}

check_requirements() {
  if [[ $EUID -ne 0 ]]; then
      echo "This script must be run as root"
  fi

  echo "Updating system clock..."
  timedatectl set-ntp true
}

confirm_installation() {
  echo "Installation Summary:"
  echo "  Hostname: $HOSTNAME"
  echo "  Username: $USERNAME"
  echo "  Target disk: $DISK"
  echo "  EFI: ${EFI_SIZE}, System: ${SYSVOL_SIZE}, User: remaining (encrypted)"

  echo "This will DESTROY ALL DATA on $DISK"
  confirm "Continue with installation?"
}

perform_installation() {
  setup_partitions
  setup_encryption
  create_filesystems
  mount_filesystems
  #move_log
  install_base_system
  configure_system
}

cleanup_and_finish() {
  sleep 5
  echo "Installation complete!"
  echo "Installing ML4W Hyprland user configuration and rebooting."
  arch-chroot /mnt sudo -u $USERNAME ml4w-hyprland-setup -m dotfiles -p arch
  cryptsetup open "$USRVOL_PART" usrvol <<< "$LUKS_PASSWORD"
  mount -t btrfs -o subvol=@home /dev/mapper/usrvol /mnt/home
  echo "exec-once = kitty bash /home/${USERNAME}/post_install.sh" >> "/mnt/home/${USERNAME}/.config/hypr/hyprland.conf"
  umount -R /mnt
  systemctl reboot
}

# Run main function
main "$@"
