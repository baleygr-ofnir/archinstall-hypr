#!/bin/bash
# lib/install.sh - Base system installation and configuration functions

# Install base system
install_base_system() {
    echo "Installing base system..."
    pacstrap /mnt base linux-zen linux-zen-headers linux-firmware btrfs-progs base-devel

    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Configure the installed system
configure_system() {
    echo "Configuring system..."

    create_chroot_script
    arch-chroot /mnt /configure_system.sh
    rm /mnt/configure_system.sh
}

# Create configuration script for chroot environment
create_chroot_script() {
    cat > /mnt/configure_system.sh << 'CHROOT_EOF'
#!/bin/bash
# Configuration script for chroot environment

set -e

# Set timezone
echo "Setting timezone..."
ln -sf /usr/share/zoneinfo/TIMEZONE_PLACEHOLDER /etc/localtime
hwclock --systohc

# Set locale
echo "Setting locale..."

# Ensure git is available
sed -i -e '/^#\?\[extra\]/s/^#//' \
    -e '/^\[extra\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    -e '/^#\?\[multilib\]/s/^#//' \
    -e '/^\[multilib\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    /etc/pacman.conf
pacman -Syu --noconfirm git sudo realtime-privileges
sleep 2
pacman -S rustup
sleep 2
rustup default stable

# User configuration
echo "Creating user USERNAME_PLACEHOLDER..."
useradd -m -G realtime,storage,wheel -s /bin/bash USERNAME_PLACEHOLDER

# Set user password
echo "USERNAME_PLACEHOLDER:USER_PASSWORD_PLACEHOLDER" | passwd --stdin USERNAME_PLACEHOLDER

echo "USER_PASSWORD_PLACEHOLDER" | passwd --stdin

# Sudo config
sed -i -e '/^#\? %wheel.*) ALL.*/s/^# //' /etc/sudoers

# Install paru from AUR
git clone https://aur.archlinux.org/paru.git /tmp/paru
chown -R USERNAME_PLACEHOLDER /tmp/paru
cd /tmp/paru
sudo -u USERNAME_PLACEHOLDER makepkg
pacman -U --noconfirm paru-*.pkg.tar.zst
sleep 2

if $(sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm en_se); then
    echo "Installed en_SE locale from AUR"
    echo "en_SE.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_SE.UTF-8" > /etc/locale.conf
else
    echo "Failed to build/install en_SE, using fallback configuration"
    echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
    echo "sv_SE.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    cat > /etc/locale.conf << EOF
LANG=en_GB.UTF-8
LC_NUMERIC=sv_SE.UTF-8
LC_TIME=sv_SE.UTF-8
LC_MONETARY=sv_SE.UTF-8
LC_PAPER=sv_SE.UTF-8
LC_MEASUREMENT=sv_SE.UTF-8
EOF
fi
sleep 5

# Cleanup
rm -rf /tmp/paru

# Set hostname
echo "HOSTNAME_PLACEHOLDER" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   HOSTNAME_PLACEHOLDER.localdomain HOSTNAME_PLACEHOLDER
EOF

# Install essential packages
echo "Installing essential packages..."
pacman -Syu --needed --noconfirm \
    efibootmgr \
    networkmanager \
    nmap \
    neovim \
    plymouth \
    pacman-contrib \
    tmux \
    obs-studio \
    flatpak \
    steam \
    lutris \
    wine \
    winetricks \
    gamemode \
    lib32-gamemode \
    vulkan-tools \
    lib32-vulkan-icd-loader \
    vulkan-icd-loader

# Configure mkinitcpio for encryption with Plymouth
echo "Configuring mkinitcpio..."
sed -i \
  -e 's/^\?HOOKS=.*microcode.*kms.*consolefont.*/#&/' \
  -e '/#^\?HOOKS=.*microcode.*kms.*consolefont.*/a \\n\# CUSTOM SYSTEMD HOOK\nHOOKS=(base systemd autodetect microcode plymouth modconf kms keyboard keymap sd-vconsole sd-encrypt block filesystems fsck)/' \
#  -e '/^#\?COMPRESSION="zstd"/s/^#//' \
#  -e '/^#\?COMPRESSION_OPTIONS=.*/s/^#//' \
#  -e '/^COMPRESSION_OPTIONS=/s/()/(-15)/' \
  /etc/mkinitcpio.conf
mkinitcpio -P

# Install and configure systemd-boot
echo "Installing systemd-boot..."
bootctl install

# Get UUIDs
ROOT_UUID=$(blkid -s UUID -o value SYSVOL_PART_PLACEHOLDER)
USRVOL_UUID=$(blkid -s UUID -o value USRVOL_PART_PLACEHOLDER)

# Create boot entry
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux (Zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$ROOT_UUID rootflags=subvol=@ rw quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 preempt=full threadirqs idle=halt processor.max_cstate=1 nohz=on nohz_full=1-15 amd_pstate=active rcu_nocbs=1-15 udev.children_max=2 usbcore.autosuspend=-1 pcie_aspm=performance nvme_core.poll_queues=1 nowatchdog
EOF

# Configure systemd-boot
cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

# Configure crypttab for user volume
echo "Configuring crypttab..."
cat > /etc/crypttab << EOF
# <name>       <device>                         <password>    <options>
usrvol         UUID=$USRVOL_UUID                none          luks
EOF

# Configure Plymouth theme
su - USERNAME_PLACEHOLDER -c "paru -S --noconfirm plymouth-theme-monoarch"
plymouth-set-default-theme -R monoarch

# Enable NetworkManager
systemctl enable NetworkManager

# Enable package cache cleanup
echo "Enabling automatic package cache cleanup..."
systemctl enable --now paccache.timer

# Create swapfile
echo "Creating 8GB swapfile..."
btrfs filesystem mkswapfile --size 8g --uuid clear /.swapvol/swapfile
swapon /.swapvol/swapfile
echo "/.swapvol/swapfile none swap defaults 0 0" >> /etc/fstab

echo "Installing ML4W Hyprland..."
sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm ml4w-hyprland

setup_ml4w_post_install() {
    echo "Setting up ML4W post-installation script..."

    cat > /home/USERNAME_PLACEHOLDER/ml4w-setup.sh << 'ML4W_SCRIPT_EOF'
#!/bin/bash
# ML4W Hyprland Setup - Run after first login

check_user() {
    if [[ $EUID -eq 0 ]]; then
        echo "Don't run this as root. Run as your user account."
        exit 1
    fi
}

install_gaming_packages() {
    echo "Installing gaming-specific AUR packages..."

    AUR_GAMING_PACKAGES=(
        "protonup-qt"
        "bottles"
        "heroic-games-launcher-bin"
        "corectrl"
        "gamescope"
        "mangohud"
        "lib32-mangohud"
        "goverlay"
    )

    for package in "${AUR_GAMING_PACKAGES[@]}"; do
        echo "Installing AUR package: $package..."
        paru -S --needed --noconfirm "$package" || echo "Failed to install $package"
    done
}

configure_monitor() {
    echo "Configuring monitor for 1440p 144Hz HDR G-Sync..."

    mkdir -p ~/.config/hypr/conf
    cat << 'MONITOR_CONF_EOF' > ~/.config/hypr/conf/monitor.conf
# Monitor configuration for 1440p 144Hz HDR G-Sync
monitor = DP-1, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 2560x1440@144, 0x0, 1

# Enable HDR
env = WLR_DRM_HDR_ON, 1

# Variable Refresh Rate
misc {
    vrr = 2
}

# Gaming optimizations
decoration {
    blur {
        enabled = false
    }
    drop_shadow = false
}

general {
    gaps_in = 2
    gaps_out = 4
    border_size = 1
    allow_tearing = true
}

input {
    kb_layout = se
    kb_variant = us
    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    force_no_accel = true
}
MONITOR_CONF_EOF

    if ! grep -q "source = ~/.config/hypr/conf/monitor.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/conf/monitor.conf" >> ~/.config/hypr/hyprland.conf
    fi
}

configure_gaming_rules() {
    echo "Configuring gaming window rules..."

    cat << 'GAMING_CONF_EOF' > ~/.config/hypr/conf/gaming.conf
# Gaming window rules
windowrulev2 = immediate, class:^(steam_app_.*)$
windowrulev2 = fullscreen, class:^(steam_app_.*)$
windowrulev2 = idleinhibit always, class:^(steam_app_.*)$
windowrulev2 = noanim, class:^(steam_app_.*)$

# Lutris
windowrulev2 = immediate, class:^(lutris)$
windowrulev2 = idleinhibit always, class:^(lutris)$

# Gamescope
windowrulev2 = immediate, class:^(gamescope)$
windowrulev2 = fullscreen, class:^(gamescope)$
windowrulev2 = idleinhibit always, class:^(gamescope)$
GAMING_CONF_EOF

    if ! grep -q "source = ~/.config/hypr/conf/gaming.conf" ~/.config/hypr/hyprland.conf; then
        echo "source = ~/.config/hypr/conf/gaming.conf" >> ~/.config/hypr/hyprland.conf
    fi
}

create_gaming_scripts() {
    echo "Creating gaming helper scripts..."

    mkdir -p ~/.config/hypr/scripts

    cat << 'GAMING_SCRIPT_EOF' > ~/.config/hypr/scripts/gaming-mode.sh
#!/bin/bash
GAMING_MODE_FILE="/tmp/gaming_mode"

if [ -f "$GAMING_MODE_FILE" ]; then
    rm "$GAMING_MODE_FILE"
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword decoration:drop_shadow true
    hyprctl keyword animations:enabled true
    notify-send "Gaming Mode" "Disabled"
else
    touch "$GAMING_MODE_FILE"
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword decoration:drop_shadow false
    hyprctl keyword animations:enabled false
    notify-send "Gaming Mode" "Enabled"
fi
GAMING_SCRIPT_EOF

    chmod +x ~/.config/hypr/scripts/gaming-mode.sh
}

optimize_system() {
    echo "Applying gaming optimizations..."

    sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null << 'SYSCTL_CONF_EOF'
vm.swappiness = 1
vm.vfs_cache_pressure = 50
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216
SYSCTL_CONF_EOF

    sudo systemctl enable docker
    systemctl --user enable gamemoded
}

main() {
    echo "Starting ML4W Hyprland Gaming/Workstation setup..."

    check_user
    install_aur_helper
    install_gaming_packages
    install_ml4w_hyprland
    configure_monitor
    configure_gaming_rules
    create_gaming_scripts
    optimize_system

    echo "ML4W setup completed!"
    echo "Use Super+F1 to toggle gaming mode"
    echo "Reboot recommended for all optimizations"
}

main "$@"
ML4W_SCRIPT_EOF

    chmod +x /home/USERNAME_PLACEHOLDER/ml4w-setup.sh
    chown USERNAME_PLACEHOLDER:USERNAME_PLACEHOLDER /home/USERNAME_PLACEHOLDER/ml4w-setup.sh

    echo "ML4W setup script created at /home/USERNAME_PLACEHOLDER/ml4w-setup.sh"
}

# Setup ML4W post-installation script
setup_ml4w_post_install

echo "Base configuration complete!"
echo "Post-installation:"
echo "  - Run ~/ml4w-setup.sh after first login for ML4W Hyprland"
echo "Post-installation recommendations:"
echo "  - Configure swapfile in /.swapvol if needed"
echo "  - Set up btrfs snapshots with timeshift or snapper"
echo "  - Install desktop environment"

CHROOT_EOF

    # Replace placeholders
    sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /mnt/configure_system.sh
    sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/configure_system.sh
    sed -i "s/USER_PASSWORD_PLACEHOLDER/$USER_PASSWORD/g" /mnt/configure_system.sh
    sed -i "s|SYSVOL_PART_PLACEHOLDER|$SYSVOL_PART|g" /mnt/configure_system.sh
    sed -i "s|USRVOL_PART_PLACEHOLDER|$USRVOL_PART|g" /mnt/configure_system.sh

    chmod +x /mnt/configure_system.sh
}