#!/bin/bash
# setup.sh - Setup and run the modular Arch Linux installation

set -e

INSTALL_DIR="${PWD}"

# Download or create all script files
#create_scripts() {
    # You would typically download these from a repository
    # For now, create them locally or copy from your development directory

  #  echo "Setting up installation scripts..."
 #   echo "Please ensure all script files are in the correct locations:"
#    echo "  $INSTALL_DIR/main.sh"
    #echo "  $INSTALL_DIR/lib/common.sh"
   # echo "  $INSTALL_DIR/lib/config.sh"
  #  echo "  $INSTALL_DIR/lib/partitioning.sh"
 #   echo "  $INSTALL_DIR/lib/install.sh"
#    echo "  $INSTALL_DIR/lib/ml4w-hyprland.sh"
#}

# Make scripts executable
set_permissions() {
    chmod +x "$INSTALL_DIR/main.sh"
    chmod +x "$INSTALL_DIR/lib/*.sh"
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

#    setup_directory
#    create_scripts
    set_permissions

    echo "Starting Arch Linux installation..."
    run_installation "$@"
}

main "$@"
