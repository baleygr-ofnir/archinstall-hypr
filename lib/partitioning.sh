#!/bin/bash
# lib/partitioning.sh - Disk partitioning and filesystem setup functions

# Partition setup
setup_partitions() {
    status "Partitioning disk $DISK..."

    # Unmount any mounted filesystems
    umount -R /mnt 2>/dev/null || true

    # Close any open encrypted volumes
    cryptsetup close usrvol 2>/dev/null || true

    # Wipe filesystem signatures
    wipefs -af "$DISK"

    # Clear any existing partition table
    sgdisk -Z "$DISK"
    sgdisk -o "$DISK"

    # Create partitions using sgdisk for GPT
    sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 -c 1:"EFI System" "$DISK"
    sgdisk -n 2:0:+"$SYSVOL_SIZE" -t 2:8304 -c 2:"Linux root" "$DISK"
    sgdisk -n 3:0:0 -t 3:8309 -c 3:"Linux LUKS" "$DISK"

    # Inform kernel of changes
    partprobe "$DISK"
    sleep 5

    # Set partition variables
    EFI_PART=$(get_partition_name "$DISK" 1)
    SYSVOL_PART=$(get_partition_name "$DISK" 2)
    USRVOL_PART=$(get_partition_name "$DISK" 3)

    # Wipe partition signatures
    wipefs -af "$EFI_PART" "$SYSVOL_PART" "$USRVOL_PART"

    status "Partitions created:"
    status "  EFI: $EFI_PART"
    status "  SYSVOL: $SYSVOL_PART"
    status "  USRVOL: $USRVOL_PART"
}

# Setup LUKS encryption for user volume
setup_encryption() {
    status "Setting up LUKS encryption for user volume..."

    echo "$LUKS_PASSWORD" | cryptsetup luksFormat --batch-mode "$USRVOL_PART"
    echo "$LUKS_PASSWORD" | cryptsetup open "$USRVOL_PART" usrvol
}

# Create btrfs filesystems
create_filesystems() {
    status "Creating filesystems..."

    # Format EFI partition
    mkfs.fat -F32 "$EFI_PART"

    # Create btrfs filesystems
    mkfs.btrfs -L sysvol -f "$SYSVOL_PART"
    mkfs.btrfs -L usrvol -f /dev/mapper/usrvol

    # Create system subvolumes
    mount "$SYSVOL_PART" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@root
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@var/cache
    btrfs subvolume create /mnt/@var/log
    btrfs subvolume create /mnt/@var/tmp
    btrfs subvolume create /mnt/@tmp
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@swap
    umount /mnt

    # Create user subvolumes
    mount /dev/mapper/usrvol /mnt
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@opt
    umount /mnt
}

# Mount all filesystems
mount_filesystems() {
    status "Mounting filesystems..."

    # Mount root subvolume
    mount -o "$BTRFS_OPTS",subvol=@ "$SYSVOL_PART" /mnt

    # Create mount points
    mkdir -p /mnt/{boot,var,var/{cache,log,tmp},tmp,home,opt,root,.snapshots,.swapvol}

    # Mount system subvolumes
    mount -o "$BTRFS_OPTS",subvol=@var "$SYSVOL_PART" /mnt/var
    mount -o "$BTRFS_OPTS",subvol=@var/cache "$SYSVOL_PART" /mnt/var/cache
    mount -o "$BTRFS_OPTS",subvol=@var/log "$SYSVOL_PART" /mnt/var/log
    mount -o "$BTRFS_OPTS",subvol=@var/tmp "$SYSVOL_PART" /mnt/var/tmp
    mount -o "$BTRFS_OPTS",subvol=@tmp "$SYSVOL_PART" /mnt/tmp
    mount -o "$BTRFS_OPTS",subvol=@snapshots "$SYSVOL_PART" /mnt/.snapshots
    mount -o "$BTRFS_OPTS",subvol=@swap "$SYSVOL_PART" /mnt/.swapvol

    # Mount user subvolumes
    mount -o "$BTRFS_OPTS",subvol=@home /dev/mapper/usrvol /mnt/home
    mount -o "$BTRFS_OPTS",subvol=@opt /dev/mapper/usrvol /mnt/opt

    # Mount EFI partition
    mount "$EFI_PART" /mnt/boot

    status "Filesystem layout:"
    lsblk
}
