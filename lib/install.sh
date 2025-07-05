#!/bin/bash
# lib/install.sh - Base system installation and configuration functions

# Install base system
install_base_system() {
  echo "Installing base system..."
  pacstrap /mnt base \
    linux-zen \
    linux-zen-headers \
    linux-firmware \
    btrfs-progs \
    base-devel \
    sudo
  # Sudo config
  sed -i -e '/^#\? %wheel.*) ALL.*/s/^# //' /mnt/etc/sudoers
  # Prereqs for arch-chroot env
  echo "Enabling extra and multilib repositories"
  sed -i \
    -e '/^#\?\[extra\]/s/^#//' \
    -e '/^\[extra\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    -e '/^#\?\[multilib\]/s/^#//' \
    -e '/^\[multilib\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    /mnt/etc/pacman.conf
  arch-chroot /mnt pacman -Syu --noconfirm --needed \
    efibootmgr \
    firewalld \
    networkmanager \
    nmap \
    neovim \
    plymouth \
    pacman-contrib \
    git \
    realtime-privileges \
    rustup \
    zsh
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

  # rust install
  rustup default stable
  rustup install stable
  sleep 2

  # User configuration
  echo "Creating user USERNAME_PLACEHOLDER..."
  useradd -m -G realtime,storage,wheel -s /bin/zsh USERNAME_PLACEHOLDER
  chpasswd --encrypted << 'USER_EOF'
  USERNAME_PLACEHOLDER:$(mkpasswd -m sha-512 -s <<< "USER_PASSWORD_PLACEHOLDER")
  USER_EOF
  # Root configuration
  chpasswd --encrypted << 'ROOT_EOF'
  root:$(mkpasswd -m sha-512 -s <<< "ROOT_PASSWORD_PLACEHOLDER")
  ROOT_EOF

  # Install paru - rust-based AUR helper
  git clone https://aur.archlinux.org/paru.git /tmp/paru
  chown -R USERNAME_PLACEHOLDER /tmp/paru
  cd /tmp/paru
  sudo -u USERNAME_PLACEHOLDER makepkg -s
  pacman -U --noconfirm paru-*.pkg.tar.zst
  sleep 2
  sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm oh-my-zsh-git

  # Set locale
  echo "Setting locale..."
  if $(sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm en_se); then
    echo "Installed en_SE locale from AUR"
    sleep 2
    echo "Enabling it in system"
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "en_SE.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "Configuring as system language"
    echo "LANG=en_SE.UTF-8" > /etc/locale.conf
  else
    echo "Failed to build/install en_SE, using fallback configuration"
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
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
  cat << EOF > /etc/vconsole.conf
  KEYMAP=sv-latin1
  EOF
  sleep 2

  # Set hostname
  echo "HOSTNAME_PLACEHOLDER" > /etc/hostname
  # Configure hosts file
  cat > /etc/hosts << 'HOSTS_EOF'
  127.0.0.1   localhost
  ::1         localhost
  127.0.1.1   HOSTNAME_PLACEHOLDER.mimirsbrunnr.lan HOSTNAME_PLACEHOLDER
  HOSTS_EOF

  # Mkinitcpio configuration
  sed -i -f - /etc/mkinitcpio.conf << 'HOOKS_EOF'
  s/^HOOKS=.*microcode.*kms.*consolefont.*/#&/
  /^#\?HOOKS=.*microcode.*kms.*consolefont.*/a\
  \
  # CUSTOM SYSTEMD HOOK
  HOOKS=(base systemd autodetect microcode plymouth modconf kms keyboard keymap sd-vconsole sd-encrypt block filesystems fsck)
  /^#\?COMPRESSION="zstd"/s/^#//
  /^#\?COMPRESSION_OPTIONS=.*/s/^#//
  /^COMPRESSION_OPTIONS=/s/()/(-15)/
  HOOKS_EOF
  # Install essential gaming prereq packages
  echo "Installing essential packages..."
  pacman -Syu --needed --noconfirm \
    tmux \
    obs-studio \
    flatpak \
    steam \
    lutris \
    wine \
    winetricks \
    wine-mono \
    wine-gecko \
    gamemode \
    lib32-gamemode \
    mesa \
    lib32-mesa \
    xf86-video-amdgpu \
    vulkan-tools \
    lib32-vulkan-icd-loader \
    vulkan-icd-loader \
    vulkan-radeon \
    lib32-vulkan-radeon \
    ttf-liberation \
    ttf-liberation-mono-nerd \
    libvirt \
    libvirt-dbus \
    libvirt-glib \
    libvirt-python \
    libvirt-storage-gluster \
    libvirt-storage-iscsi-direct \
    qemu-audio-alsa \
    qemu-audio-dbus \
    qemu-audio-pipewire \
    qemu-audio-sdl \
    qemu-audio-spice \
    qemu-base \
    qemu-block-curl \
    qemu-block-iscsi \
    qemu-block-nfs \
    qemu-block-ssh \
    qemu-chardev-baum \
    qemu-chardev-spice \
    qemu-common \
    qemu-desktop \
    qemu-docs \
    qemu-emulators-full \
    qemu-guest-agent \
    qemu-hw-display-qxl \
    qemu-hw-display-virtio-gpu \
    qemu-hw-display-virtio-gpu-gl \
    qemu-hw-display-virtio-gpu-pci \
    qemu-hw-display-virtio-gpu-pci-gl \
    qemu-hw-uefi-vars \
    qemu-hw-usb-host \
    qemu-hw-usb-redirect \
    qemu-img \
    qemu-system-x86 \
    qemu-system-x86-firmware \
    qemu-tools \
    qemu-ui-egl-headless \
    qemu-ui-gtk \
    qemu-ui-opengl \
    qemu-ui-sdl \
    qemu-ui-spice-app \
    qemu-ui-spice-core \
    qemu-user \
    qemu-user-static \
    qemu-user-static-binfmt \
    virt-manager \
    dnsmasq \
    openbsd-netcat \
    dmidecode
  sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm \
    jdk-temurin \
    ttf-ms-win10-auto \
    ttf-ms-win11-auto

  # Install and configure systemd-boot
  echo "Installing systemd-boot..."
  bootctl install

  # Get UUIDs
  ROOT_UUID=$(blkid -s UUID -o value SYSVOL_PART_PLACEHOLDER)
  USRVOL_UUID=$(blkid -s UUID -o value USRVOL_PART_PLACEHOLDER)

  # Create boot entry
  cat > /boot/loader/entries/arch.conf << 'BOOTENTRY_EOF'
  title   Arch Linux (Zen)
  linux   /vmlinuz-linux-zen
  initrd  /initramfs-linux-zen.img
  options root=UUID=$ROOT_UUID rootflags=subvol=@ rw quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 preempt=full threadirqs idle=halt processor.max_cstate=1 nohz=on nohz_full=1-15 amd_pstate=active rcu_nocbs=1-15 udev.children_max=2 usbcore.autosuspend=-1 pcie_aspm=performance nvme_core.poll_queues=1 nowatchdog
  BOOTENTRY_EOF

  # Configure systemd-boot
  cat > /boot/loader/loader.conf << 'SYSTEMD_EOF'
  default arch.conf
  timeout 3
  console-mode max
  editor no
  SYSTEMD_EOF

  # Configure crypttab for user volume
  echo "Configuring crypttab..."
  cat > /etc/crypttab << 'CRYPTTAB_EOF'
  # <name>       <device>                         <password>    <options>
  usrvol         UUID=$USRVOL_UUID                none          luks
  CRYPTTAB_EOF

  # Configure Plymouth theme
  echo "Setting Monoarch Plymouth theme..."
  sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm plymouth-theme-monoarch
  plymouth-set-default-theme -R monoarch

  # Enable NetworkManager
  systemctl enable NetworkManager
  systemctl enable firewalld

  # Enable package cache cleanup
  echo "Enabling automatic package cache cleanup..."
  systemctl enable paccache.timer

  # Create swapfile
  echo "Creating 8GB swapfile..."
  btrfs filesystem mkswapfile --size 8g --uuid clear /.swapvol/swapfile
  swapon /.swapvol/swapfile
  echo "/.swapvol/swapfile none swap defaults 0 0" >> /etc/fstab

  echo "Installing ML4W Hyprland..."
  sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm ml4w-hyprland
  sleep 2
  sudo -u USERNAME_PLACEHOLDER ml4w-hyprland-setup
  # Cleanup
  echo "Cleaning up package cache..."
  sudo -u USERNAME_PLACEHOLDER paru -Scc --noconfirm
  rm -rf /tmp/paru
  # Rebuild initramfs
  mkinitcpio -P

  echo "Base configuration complete!\nPost-installation recommendations:\n  - Set up btrfs snapshots with timeshift or snapper"
CHROOT_EOF
  # Replace placeholders
  sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /mnt/configure_system.sh
  sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/configure_system.sh
  sed -i "s/USER_PASSWORD_PLACEHOLDER/$USER_PASSWORD/g" /mnt/configure_system.sh
  sed -i "s/ROOT_PASSWORD_PLACEHOLDER/$ROOT_PASSWORD/g" /mnt/configure_system.sh
  sed -i "s|TIMEZONE_PLACEHOLDER|$TIMEZONE|g" /mnt/configure_system.sh
  sed -i "s|SYSVOL_PART_PLACEHOLDER|$SYSVOL_PART|g" /mnt/configure_system.sh
  sed -i "s|USRVOL_PART_PLACEHOLDER|$USRVOL_PART|g" /mnt/configure_system.sh
  chmod +x /mnt/configure_system.sh
}