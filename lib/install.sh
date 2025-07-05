#!/bin/bash
# lib/install.sh - Base system installation and configuration functions


# Install base system
install_base_system() {
    echo "Installing base system..."
    pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware btrfs-progs amd-ucode

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
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# Set locale
status "Setting locale..."

# Ensure git is available
sed -i -e '/^#\?\[extra\]/s/^#//' \
    -e '/^\[extra\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    -e '/^#\?\[multilib\]/s/^#//' \
    -e '/^\[multilib\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' /etc/pacman.conf
pacman -Sy --noconfirm git

# Try to install en_SE locale from AUR
cd /tmp
git clone https://aur.archlinux.org/en_se.git
cd en_se
chown -R nobody .
# Attempt install otherwise configure with default locales
if sudo -u nobody makepkg && pacman -U --noconfirm *.tar.xz; then
    status "Installed en_SE locale from AUR"
    echo "en_SE.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_SE.UTF-8" > /etc/locale.conf
else
    status "Failed to build/install en_SE, using fallback configuration"
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
# Cleanup
rm -rf /tmp/en_se

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
pacman -S --noconfirm --needed \
    efibootmgr \
    networkmanager \
    sudo \
    neovim \
    plymouth \
    pacman-contrib

# Configure mkinitcpio for encryption
echo "Configuring mkinitcpio..."
sudo sed -i \
	-e 's/^\?HOOKS=.*microcode.*kms.*consolefont.*/#&/' \
    -e '/^#\?HOOKS=.*microcode.*kms.*consolefont.*/a \\n\# CUSTOM SYSTEMD HOOK\nHOOKS=(base systemd autodetect microcode plymouth modconf kms keyboard keymap sd-vconsole sd-encrypt block filesystems fsck)/' \
    -e '/^#\?COMPRESSION="zstd"/s/^#//' \
	-e '/^#\?COMPRESSION_OPTIONS=.*/s/^#//' \
    -e '/^COMPRESSION_OPTIONS=/s/()/(-15)/' \
    /etc/mkinitcpio.conf
mkinitcpio -P

# Install and configure systemd-boot
status "Installing systemd-boot..."
bootctl install

# Get UUIDs
SYSVOL_UUID=$(blkid -s UUID -o value SYSVOL_PART_PLACEHOLDER)
USRVOL_UUID=$(blkid -s UUID -o value USRVOL_PART_PLACEHOLDER)

# Create boot entry
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux (Zen)
linux   /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=UUID=$SYSVOL_UUID rootflags=subvol=@ rw quiet splash loglevel=3 preempt=full nohz=on nohz_full=1-15 threadirqs idle=halt processor.max_cstate=1 amd_pstate=active rcu_nocbs=1-15 udev.children_max=2 usbcore.autosuspend=-1 pcie_aspm=performance nvme_core.poll_queues=1 nowatchdog rd.udev.log_priority=3 vt.global_cursor_default=0
EOF

# Configure systemd-boot
cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

# Configure crypttab for user volume
status "Configuring crypttab..."
cat > /etc/crypttab << EOF
# <name>       <device>                         <password>    <options>
usrvol         UUID=$USRVOL_UUID                none          luks
EOF

# Configure Plymouth theme
plymouth-set-default-theme monoarch
plymouth-set-default-theme --rebuild-initrd

# Enable NetworkManager
systemctl enable NetworkManager

# Create user
echo "Creating user USERNAME_PLACEHOLDER..."
useradd -m -G docker,input,libvirt,realtime,storage,wheel -s /bin/bash USERNAME_PLACEHOLDER

# Set user password
echo "USERNAME_PLACEHOLDER:USER_PASSWORD_PLACEHOLDER" | chpasswd

# Set root password
echo "Enter root password:"
passwd

# Configure sudo
#echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
sed -i -e '/^# \?\%wheel ALL.*) ALL$/s/^# //' /etc/sudoers

# Create swapfile
status "Creating 8GB swapfile..."
btrfs filesystem mkswapfile --size 8g --uuid clear /.swapvol/swapfile
swapon /.swapvol/swapfile
echo "/.swapvol/swapfile none swap defaults 0 0" >> /etc/fstab

echo "Base configuration complete!"
echo "Post-installation recommendations:"
echo "  - Configure swapfile in /.swapvol if needed"
echo "  - Set up btrfs snapshots with timeshift or snapper"
echo "  - Install desktop environment"

CHROOT_EOF

    # Replace placeholders
    sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /mnt/configure_system.sh
    sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/configure_system.sh
    sed -i "s/USER_PASSWORD_PLACEHOLDER/$USER_PASSWORD/g" /mnt/configure_system.sh
    sed -i "s|USRVOL_PART_PLACEHOLDER|$USRVOL_PART|g" /mnt/configure_system.sh

    chmod +x /mnt/configure_system.sh
}
