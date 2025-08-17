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
  # Generate fstab
  genfstab -U /mnt >> /mnt/etc/fstab
}

# Configure the installed system
configure_system() {
  echo "Configuring system..."
  create_chroot_script
  arch-chroot /mnt /configure_system.sh
  rm /mnt/configure_system.sh
  cp "${SCRIPT_DIR}/lib/post_install.sh" "/mnt/home/${USERNAME}/"
  arch-chroot /mnt chown "$USERNAME":"$USERNAME" "/home/${USERNAME}/post_install.sh"
  cp -r "${SCRIPT_DIR}/lib/.local" "/mnt/home/${USERNAME}/"
  arch-chroot /mnt chown -R "$USERNAME":"$USERNAME" "/home/${USERNAME}/.local/"
  echo "exec-once = kitty bash /home/${USERNAME}/post_install.sh" >> "/mnt/home/${USERNAME}/.config/hypr/conf"
}

# Create configuration script for chroot environment
create_chroot_script() {
  cat > /mnt/configure_system.sh << EOF
  #!/bin/bash
  # Configuration script for chroot environment
  set -e

  # Set timezone
  echo "Setting timezone..."
  ln -sf /usr/share/zoneinfo/TIMEZONE_PLACEHOLDER /etc/localtime
  hwclock --systohc

  # Prereqs for arch-chroot env
  echo "Enabling extra and multilib repositories as well as ignoring unwanted packages from ML4W Hyprland setup..."
  sed -i \
    -e '/^#\?\[extra\]/s/^#//' \
    -e '/^\[extra\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    -e '/^#\?\[multilib\]/s/^#//' \
    -e '/^\[multilib\]/,+1{/^#\?Include.*mirrorlist/s/^#//}' \
    -e '/^#\?\IgnorePkg.*/s/^#//' \
    -e 's/^IgnorePkg.*=/& firefox nautilus nautilus-python nautilus-open-any-terminal xdg-desktop-portal-gtk /' /etc/pacman.conf
  pacman -Syu --noconfirm --needed \
    amd-ucode \
    efibootmgr \
    firewalld \
    dolphin \
    networkmanager \
    nmap \
    neovim \
    plymouth \
    pacman-contrib \
    git \
    gum \
    realtime-privileges \
    timeshift \
    tmux \
    zsh \
    zsh-autocomplete \
    zsh-autosuggestions \
    zsh-completions \
    zsh-doc \
    zsh-history-substring-search \
    zsh-syntax-highlighting

  # User configuration
  echo "Creating user USERNAME_PLACEHOLDER..."
  useradd -m -G realtime,storage,wheel -s /bin/zsh "USERNAME_PLACEHOLDER"
  echo 'USERNAME_PLACEHOLDER:USER_PASSWORD_PLACEHOLDER' | chpasswd -c SHA512

  # Root configuration
  echo 'root:ROOT_PASSWORD_PLACEHOLDER' | chpasswd -c SHA512
  
  # Sudo config
  sed -i -e '/^#\? %wheel.*) ALL.*/s/^# //' /etc/sudoers
  sleep 2

  # Set locale
  echo "Setting locale..."
  mv /etc/locale.gen /etc/locale.gen.bak
  # sudo -u USERNAME_PLACEHOLDER paru -S --noconfirm en_se
  git clone https://aur.archlinux.org/en_se.git /tmp/en_se
  chown -R nobody /tmp/en_se
  cd /tmp/en_se
  sudo -u nobody makepkg -s
  cd
  if pacman -U --noconfirm "/tmp/en_se/en_se-"*.pkg.tar.zst; then
    echo "Installed en_SE locale from AUR"
    sleep 2
    echo "Enabling it in system"
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "en_SE.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    sleep 2
    echo "Configuring as system language"
    echo "LANG=en_SE.UTF-8" > /etc/locale.conf
  else
    echo "Failed to build/install en_SE, using fallback configuration"
    for fallback_locale-gen in \
        "en_US.UTF-8 UTF-8" \
        "en_GB.UTF-8 UTF-8" \
        "sv_SE.UTF-8 UTF-8"
    do
      echo "${fallback_locale-gen}" >> /etc/locale.gen
    done
    locale-gen
    sleep 2
    for fallback_locale-conf in \
      "LANG=en_GB.UTF-8" \
      "LC_NUMERIC=sv_SE.UTF-8" \
      "LC_TIME=sv_SE.UTF-8" \
      "LC_MONETARY=sv_SE.UTF-8" \
      "LC_PAPER=sv_SE.UTF-8" \
      "LC_MEASUREMENT=sv_SE.UTF-8"
    do
      echo "${fallback_locale-conf}" >> /etc/locale.conf
    done
  fi
  cd
  rm -rf /tmp/en_se

  # Install and configure systemd-boot
  echo "Installing systemd-boot..."
  bootctl install
  
  # Create swapfile
  echo "Creating 8GB swapfile..."
  btrfs filesystem mkswapfile --size 8g --uuid clear /.swapvol/swapfile
  swapon /.swapvol/swapfile
  echo "/.swapvol/swapfile none swap defaults 0 0" >> /etc/fstab

  # Configure Plymouth theme
  echo "Setting Monoarch Plymouth theme..."
  git clone https://aur.archlinux.org/plymouth-theme-monoarch.git /tmp/plymouth-theme-monoarch
  chown -R nobody /tmp/plymouth-theme-monoarch
  cd /tmp/plymouth-theme-monoarch
  sudo -u nobody makepkg -s
  cd
  pacman -U --noconfirm "/tmp/plymouth-theme-monoarch/"*.pkg.tar.zst

  # Enable NetworkManager
  systemctl enable NetworkManager
  systemctl enable firewalld

  # Enable package cache cleanup
  echo "Enabling automatic package cache cleanup..."
  systemctl enable paccache.timer

  # Bluetooth configuration
  if gum confirm "Install bluetooth packages?"; then
    pacman -S \
      bluez \
      bluez-libs \
      bluez-utils \
      blueman
    systemctl enable bluetooth
  fi

  gum confirm "Last part needs user password input atleast 3 times, continue?" && echo "Continuing..."

  # Paru install
  echo "----Installing paru - rust-based AUR helper (User password required)----"
  sleep 2
  git clone https://aur.archlinux.org/paru.git /tmp/paru
  chown -R USERNAME_PLACEHOLDER /tmp/paru
  cd /tmp/paru
  sudo -u USERNAME_PLACEHOLDER makepkg -si --noconfirm
  cd
  sleep 2

  # yay install
  echo "----Installing yay - AUR helper (User password required)----"
  sleep 2
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  chown -R USERNAME_PLACEHOLDER /tmp/yay
  cd /tmp/yay
  sudo -u USERNAME_PLACEHOLDER makepkg -si --noconfirm
  cd
  sleep 2

  # end-4 hyprland dots install
  echo "----Installing end-4 hyprland dots - AUR helper (User password required)----"
  sudo -u USERNAME_PLACEHOLDER bash <(curl -s "https://end-4.github.io/dots-hyprland-wiki/setup.sh")

# Cleanup
  echo "Cleaning up package cache..."
  sudo -u USERNAME_PLACEHOLDER paru -Scc --noconfirm
  # Rebuild initramfs
  plymouth-set-default-theme -R monoarch
EOF
  
  # Replace chroot script placeholders
  sed -i -e "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/configure_system.sh
  sed -i -e "s/USER_PASSWORD_PLACEHOLDER/$USER_PASSWORD/g" /mnt/configure_system.sh
  sed -i -e "s/ROOT_PASSWORD_PLACEHOLDER/$ROOT_PASSWORD/g" /mnt/configure_system.sh
  sed -i -e "s|TIMEZONE_PLACEHOLDER|$TIMEZONE|g" /mnt/configure_system.sh
  chmod +x /mnt/configure_system.sh
  
  # Copy systemd-boot files into system and configuring
  cp -r "${SCRIPT_DIR}/conf/boot" /mnt
  efibootmgr --create --disk $DISK --part 1 --label "netboot.xyz" --loader /EFI/netboot.xyz/netboot.xyz.efi
  chown -R 0:0 /mnt/boot/loader
  sed -i -e "s/SYSVOL_UUID_PLACEHOLDER/$(blkid -s UUID -o value $SYSVOL_PART)/" /mnt/boot/loader/entries/arch.conf

  # Copy system conf files into system and configuring
  cp -r "${SCRIPT_DIR}/conf/etc" /mnt
  chown -R 0:0 /mnt/etc/{crypttab,mkinitcpio.conf,hosts,vconsole.conf}
  sed -i -e "s/USRVOL_UUID_PLACEHOLDER/$(blkid -s UUID -o value $USRVOL_PART)/" /mnt/etc/crypttab
  sed -i -e "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" \
    -e "s/LANDOMAIN_PLACEHOLDER/$LANDOMAIN/g" \
    -e "s/DOMAINSUFFIX_PLACEHOLDER/$DOMAINSUFFIX/g" /mnt/etc/hosts
  echo "$HOSTNAME" > /mnt/etc/hostname
}
