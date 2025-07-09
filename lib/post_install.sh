# Install packages
paru -Syu --needed --noconfirm \
    # audio system
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    pipewire-libcamera \
    pipewire-v4l2 \
    gst-plugin-pipewire \
    libpipewire \
    wireplumber \
    wireplumber-docs \
    libwireplumber \
    pavucontrol \
    sof-firmware \
    # bluetooth 
    bluez \
    bluez-libs \
    bluez-utils \
    bluetoothctl \
    blueman \
    libinput \
    dolphin \
    tmux \
    otf-font-awesome \
    ttf-liberation \
    ttf-liberation-mono-nerd \
    ttf-jetbrains-mono-nerd \
    ttf-ms-win11-auto \
    flatpak \
    vivaldi-snapshot \
    signal-desktop \
    vesktop \
    zapzap \
    mpv \
    oh-my-zsh-git \
    p7zip \
    rsync \
    zoxide \
    wget

systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

gum confirm "Install OnlyOffice desktop editors?" && paru -S --noconfirm onlyoffice-bin

gum confirm "Install development tools?" && paru -S --noconfirm \
    code \
    drawio-desktop-bin \
    jdk-temurin \
    jetbrains-toolkit \

# KVM
gum confirm "Install packages for KVM/QEMU with virt-manager?" && paru -S --noconfirm \
    virt-manager \
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
    dnsmasq \
    openbsd-netcat \
    dmidecode && \
    sudo systemctl enable --now libvirtd.service libvirtd.socket

# Gaming
gum confirm "Install packages for gaming?" && paru -S --noconfirm \
    steam \
    lutris \
    heroic-games-launcher-bin \
    wine \
    winetricks \
    wine-mono \
    wine-gecko \
    gamemode \
    lib32-gamemode \
    mangohud \
    mesa \
    lib32-mesa \
    xf86-video-amdgpu \
    vulkan-tools \
    lib32-vulkan-icd-loader \
    vulkan-icd-loader \
    vulkan-radeon \
    lib32-vulkan-radeon

echo "" > ${HOME}/.zlogin

gum confirm "Reboot recommended, continue?" && systemctl reboot
