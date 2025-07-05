#!/bin/bash
# setup.sh - Setup and run the modular Arch Linux installation

set -e

INSTALL_DIR="${PWD}"

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

#    setup_directory
#    create_scripts
    set_permissions

    echo "Starting Arch Linux installation..."
    run_installation "$@"
}

main "$@"
