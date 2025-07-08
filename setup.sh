#!/bin/bash
# setup.sh - Setup and run the modular Arch Linux installation
set -e
INSTALL_DIR="/tmp/archinstall"

pacman -Sy --needed --noconfirm git

if [ ! -d /tmp/archinstall ];then
    git clone https://github.com/baleygr-ofnir/archinstall.git "$INSTALL_DIR"
else
    echo "Already downloaded in: /tmp/archinstall, continuing..."
fi

# Make scripts executable
set_permissions() {
  chmod +x "$INSTALL_DIR/main.sh"
  chmod +x "$INSTALL_DIR/lib/"*.sh
}

# Run the installation
run_installation() {
  cd "$INSTALL_DIR"
  ./main.sh "$@"
}

# Main execution
main() {
  if [[ $EUID -ne 0 ]]; then
      echo "This script must be run as root"
      exit 1
  fi

  set_permissions
  echo "Starting Arch Linux installation..."
  sleep 2
  run_installation "$@"
}

main "$@"
