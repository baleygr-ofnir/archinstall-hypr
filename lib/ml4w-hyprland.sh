#!/bin/bash

# ML4W Hyprland Gaming/Workstation Setup for Arch Linux Chroot
# Optimized for 1440p 144Hz HDR G-Sync Monitor
# Author: Assistant
# Version: 1.0

set -e

# Pre-installation system preparation
prepare_system() {
    echo "Preparing system for ML4W Hyprland installation..."

    # Update system
    pacman -Syu --noconfirm

    # Install base development tools
    pacman -S --needed --noconfirm base-devel git curl wget

    # Install paru AUR helper if not present
    if ! command -v paru &> /dev/null; then
        echo "Installing paru AUR helper..."
        cd /tmp
        git clone https://aur.archlinux.org/paru.git
        cd paru
        chown -R nobody .
        sudo -u nobody makepkg
        pacman -U *.tar.xz
        cd ~
    fi
}

# Install gaming-specific packages
install_gaming_packages() {
    echo "Installing gaming-specific packages..."

    # Gaming essentials
    GAMING_PACKAGES=(
        # Core gaming
        "steam"
        "lutris"
        "wine"
        "winetricks"
        "gamemode"
        "lib32-gamemode"

        # Performance tools
        "gamescope"
        "mangohud"
        "lib32-mangohud"
        "goverlay"

        # Graphics drivers support
        "vulkan-tools"
        "lib32-vulkan-icd-loader"
        "vulkan-icd-loader"

        # Controllers
        "xpadneo-dkms"
    )

    for package in "${GAMING_PACKAGES[@]}"; do
        echo "Installing $package..."
        sudo pacman -S --needed --noconfirm "$package" || warn "Failed to install $package"
    done

    # AUR gaming packages
    AUR_GAMING_PACKAGES=(
        "protonup-qt"
        "bottles"
        "heroic-games-launcher-bin"
        "corectrl"
    )

    for package in "${AUR_GAMING_PACKAGES[@]}"; do
        echo "Installing AUR package: $package..."
        paru -S --needed --noconfirm "$package" || warn "Failed to install $package"
    done
}

# Install ML4W Hyprland
install_ml4w_hyprland() {
    echo "Installing ML4W Hyprland..."

    # Install ML4W Hyprland via official installer
    bash -c "$(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh)"
}

# Monitor and display optimization
configure_monitor() {
    echo "Configuring monitor for 1440p 144Hz HDR G-Sync..."

    # Create custom Hyprland monitor configuration
    cat << 'EOF' > ~/.config/hypr/conf/monitor.conf
# Monitor configuration for 1440p 144Hz HDR G-Sync
# Replace MONITOR_NAME with your actual monitor identifier (use 'hyprctl monitors')

# Main gaming monitor - adjust MONITOR_NAME to your display
monitor = DP-1, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 2560x1440@144, 0x0, 1

# Enable HDR (requires Hyprland 0.47.0+)
env = WLR_DRM_HDR_ON, 1

# Variable Refresh Rate (VRR/G-Sync/FreeSync)
misc {
    vrr = 2  # VRR only for fullscreen apps (optimal for gaming)
}

# Gaming-optimized display settings
decoration {
    # Disable blur for better gaming performance
    blur {
        enabled = false
    }

    # Minimal shadows for performance
    drop_shadow = false
}

# Performance optimizations
general {
    gaps_in = 2
    gaps_out = 4
    border_size = 1

    # Disable animations during gaming (can be toggled)
    allow_tearing = true
}

# Input optimization for gaming
input {
    kb_layout = se
    kb_variant = us
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    sensitivity = 0 # -1.0 - 1.0, 0 means no modification

    # Gaming mouse settings
    accel_profile = flat
    force_no_accel = true
}

# Workspace rules for gaming
workspace = 1, monitor:DP-1, default:true
workspace = 2, monitor:DP-1
workspace = 3, monitor:DP-1
workspace = 4, monitor:DP-1
workspace = 5, monitor:DP-1

EOF

    # Source the monitor config in main hyprland.conf
    if ! grep -q "source = ~/.config/hypr/conf/monitor.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/conf/monitor.conf" >> ~/.config/hypr/hyprland.conf
    fi
}

# Gaming-specific Hyprland window rules
configure_gaming_rules() {
    echo "Configuring gaming window rules..."

    cat << 'EOF' > ~/.config/hypr/conf/gaming.conf
# Gaming-specific window rules

# Steam
windowrulev2 = float, class:^(steam)$, title:^(Steam - News)$
windowrulev2 = float, class:^(steam)$, title:^(Friends List)$
windowrulev2 = float, class:^(steam)$, title:^(Steam Settings)$

# Gaming performance rules
windowrulev2 = immediate, class:^(steam_app_.*)$
windowrulev2 = fullscreen, class:^(steam_app_.*)$
windowrulev2 = noinitialfocus, class:^(steam_app_.*)$
windowrulev2 = idleinhibit always, class:^(steam_app_.*)$

# Lutris
windowrulev2 = immediate, class:^(lutris)$
windowrulev2 = idleinhibit always, class:^(lutris)$

# Wine applications
windowrulev2 = immediate, class:^(wine)$
windowrulev2 = idleinhibit always, class:^(wine)$

# Gamescope
windowrulev2 = immediate, class:^(gamescope)$
windowrulev2 = fullscreen, class:^(gamescope)$
windowrulev2 = idleinhibit always, class:^(gamescope)$

# MangoHud
windowrulev2 = opacity 0.9, class:^(mangohud)$

# OBS Studio
windowrulev2 = idleinhibit always, class:^(obs)$
windowrulev2 = workspace 9, class:^(obs)$

# Discord
windowrulev2 = workspace 8, class:^(discord)$
windowrulev2 = workspace 8, class:^(vesktop)$

# Performance: Disable animations for games
windowrulev2 = noanim, class:^(steam_app_.*)$
windowrulev2 = noanim, class:^(gamescope)$

EOF

    # Source gaming rules in main config
    if ! grep -q "source = ~/.config/hypr/conf/gaming.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/conf/gaming.conf" >> ~/.config/hypr/hyprland.conf
    fi
}

# Gaming keybindings
configure_gaming_keybinds() {
    echo "Setting up gaming keybindings..."

    cat << 'EOF' > ~/.config/hypr/conf/gaming-keybinds.conf
# Gaming-specific keybindings

# Game mode toggle (disables compositor features for max performance)
bind = SUPER, F1, exec, ~/.config/hypr/scripts/gaming-mode.sh

# Steam shortcuts
bind = SUPER, G, exec, steam
bind = SUPER SHIFT, G, exec,

# Lutris
bind = SUPER, L, exec, lutris

# MangoHud toggle
bind = SUPER, M, exec, ~/.config/hypr/scripts/mangohud-toggle.sh

# OBS Studio
bind = SUPER, O, exec, obs

# Discord
bind = SUPER, D, exec, discord

# Quick screenshot for gaming
bind = SUPER, Print, exec, grim -g "$(slurp)" ~/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png

# Performance monitoring
bind = SUPER SHIFT, P, exec, kitty --title "Performance Monitor" --hold sh -c "watch -n 1 'sensors; echo; nvidia-smi 2>/dev/null || echo No NVIDIA GPU; echo; free -h; echo; df -h'"

EOF

    # Source gaming keybinds
    if ! grep -q "source = ~/.config/hypr/conf/gaming-keybinds.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/conf/gaming-keybinds.conf" >> ~/.config/hypr/hyprland.conf
    fi
}

# Create gaming helper scripts
create_gaming_scripts() {
    echo "Creating gaming helper scripts..."

    mkdir -p ~/.config/hypr/scripts

    # Gaming mode script
    cat << 'EOF' > ~/.config/hypr/scripts/gaming-mode.sh
#!/bin/bash

GAMING_MODE_FILE="/tmp/gaming_mode"

if [ -f "$GAMING_MODE_FILE" ]; then
    # Disable gaming mode
    rm "$GAMING_MODE_FILE"

    # Re-enable compositor features
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword decoration:drop_shadow true
    hyprctl keyword animations:enabled true

    notify-send "Gaming Mode" "Disabled - Compositor features restored"
else
    # Enable gaming mode
    touch "$GAMING_MODE_FILE"

    # Disable compositor features for performance
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword decoration:drop_shadow false
    hyprctl keyword animations:enabled false

    notify-send "Gaming Mode" "Enabled - Maximum performance"
fi
EOF

    # MangoHud toggle script
    cat << 'EOF' > ~/.config/hypr/scripts/mangohud-toggle.sh
#!/bin/bash

CONFIG_FILE="$HOME/.config/MangoHud/MangoHud.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat << 'MANGO_EOF' > "$CONFIG_FILE"
toggle_hud=Shift_R+F12
toggle_echoging=Shift_L+F2
reload_cfg=Shift_L+F4
upload_echo=Shift_L+F3

horizontal
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
gpu_text=GPU

cpu_stats
cpu_temp
cpu_mhz
cpu_power
cpu_text=CPU

vram
ram
fps
frametime=0
frame_timing=1
time

background_alpha=0.4
font_size=24

background_color=020202
position=top-left
text_color=FFFFFF
toggle_hud=Shift_R+F12
MANGO_EOF
fi

notify-send "MangoHud" "Configuration updated. Use Shift+R+F12 to toggle in games."
EOF

cat << 'EOF' > ~/.config/hypr/scripts/hdr-toggle.sh
#!/bin/bash

ENABLE_HDR_WSI=1 gamescope --fullscreen -w 2560 -h 1440 --hdr-enabled --hdr-debug-force-output --hdr-sdr-content-nits 600 --mangoapp -- env ENABLE_GAMESCOPE_WSI=1 DXVK_HDR=1 DISABLE_HDR_WSI=1 steam -gamepadui
1
EOF
    # Make scripts executable
    chmod +x ~/.config/hypr/scripts/*.sh
}

# Workstation optimizations
configure_workstation() {
    echo "Configuring workstation optimizations..."

    # Development tools
    WORKSTATION_PACKAGES=(
        "code"
        "neovim"
        "git"
        "docker"
        "docker-compose"
        "nodejs"
        "npm"
        "python"
        "python-pip"
        "rustup"
        "go"
        "jdk-temurin"
        "maven"
        "gradle"
        "tmux"
        "zsh"
        "oh-my-zsh-git"
        "vivaldi-snapshot"
        "onlyoffice-bin"
        "gimp"
        "inkscape"
        "blender"
        "obs-studio"
        "flatpak"
    )

    for package in "${WORKSTATION_PACKAGES[@]}"; do
        echo "Installing workstation package: $package..."
        if [[ "$package" == *"-git" ]]; then
            paru -S --needed --noconfirm "$package" || warn "Failed to install $package"
        else
            sudo pacman -S --needed --noconfirm "$package" || warn "Failed to install $package"
        fi
    done



    # Configure development environment
    if ! grep -q "export EDITOR=nvim" ~/.oh-my-zsh/custom/environment.zsh; then
        echo "export EDITOR=nvim" >> ~/.oh-my-zsh/custom/environment.zsh
    fi
}

# System optimizations
optimize_system() {
    echo "Applying system optimizations..."

    # Gaming-specific kernel parameters
    if [ ! -f /etc/sysctl.d/99-gaming.conf ]; then
        sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null << 'EOF'
# Gaming optimizations
vm.swappiness = 1
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 1
vm.dirty_ratio = 3

# Network optimizations
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216
net.core.wmem_default = 1048576
net.core.wmem_max = 16777216
net.core.netdev_max_backecho = 5000
EOF
    fi

    # Enable gamemode service
    sudo systemctl enable --user gamemoded
}

# Final configuration and cleanup
finalize_setup() {
    echo "Finalizing setup..."

    # Create desktop entries for gaming mode
    mkdir -p ~/.local/share/applications

    cat << 'EOF' > ~/.local/share/applications/gaming-mode.desktop
[Desktop Entry]
Name=Gaming Mode Toggle
Comment=Toggle gaming optimizations in Hyprland
Exec=/home/$USER/.config/hypr/scripts/gaming-mode.sh
Icon=applications-games
Type=Application
Categories=Game;
EOF

    # Reload Hyprland configuration
    if command -v hyprctl &> /dev/null; then
        hyprctl reload
    fi

    echo "Installation completed successfully!"
    echo
    echo "Gaming optimizations installed:"
    echo "  - 1440p 144Hz HDR VRR support configured"
    echo "  - Gaming mode toggle (Super+F1)"
    echo "  - Steam, Lutris, MangoHud, GameScope installed"
    echo "  - Performance optimizations applied"
    echo
    echo "Workstation tools installed:"
    echo "  - Development environment with VS Code, Neovim"
    echo "  - Docker, Node.js, Python, Rust, Go, Java"
    echo "  - Creative tools: GIMP, Inkscape, Blender, Kdenlive"
    echo
    echo "Please reboot to ensure all optimizations take effect"
    echo
    echo "After reboot:"
    echo "  1. Run 'hyprctl monitors' to identify your monitor"
    echo "  2. Edit ~/.config/hypr/conf/monitor.conf with correct monitor name"
    echo "  3. Use Super+F1 to toggle gaming mode"
    echo "  4. Use Shift+R+F12 in games to toggle MangoHud"
}

# Main installation function
main() {
    echo "Starting ML4W Hyprland Gaming/Workstation setup..."

    check_chroot
    prepare_system
    install_gaming_packages
    install_ml4w_hyprland
    configure_monitor
    configure_gaming_rules
    configure_gaming_keybinds
    create_gaming_scripts
    configure_workstation
    optimize_system
    finalize_setup
}

# Run main function
main "$@"
