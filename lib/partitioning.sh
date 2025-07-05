#!/bin/bash
# lib/partitioning.sh - Disk partitioning and filesystem setup functions

# Partition setup
setup_partitions() {
  echo "Partitioning disk $DISK..."

  # Unmount any mounted filesystems
  umount -R /mnt 2>/dev/null || true

  # Close any open encrypted volumes
  cryptsetup close usrvol 2>/dev/null || true

  # Wipe filesystem signatures
  wipefs -af "$DISK"

  # Clear any existing partition table
  sgdisk -Z "$DISK"
  sgdisk -a=2048 "$DISK"
  sgdisk -o "$DISK"

  # Create partitions using sgdisk for GPT
  sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 -c 1:"EFI System" "$DISK"
  sgdisk -n 2:0:+"$SYSVOL_SIZE" -t 2:8305 -c 2:"Linux root" "$DISK"
  sgdisk -n 3:0:0 -t 3:8309 -c 3:"Linux LUKS" "$DISK"

  sgdisk -p "$DISK"

  # Inform kernel of changes
  partprobe "$DISK"
  sleep 5

  # Set partition variables
  EFI_PART=$(get_partition_name "$DISK" 1)
  SYSVOL_PART=$(get_partition_name "$DISK" 2)
  USRVOL_PART=$(get_partition_name "$DISK" 3)

  wipefs -af "$EFI_PART" "$SYSVOL_PART" "$USRVOL_PART"

  echo "Partitions created:"
  echo "  EFI: $EFI_PART"
  echo "  SYSVOL: $SYSVOL_PART"
  echo "  USRVOL: $USRVOL_PART"
}

# Setup LUKS encryption for user volume
setup_encryption() {
  echo "Setting up LUKS encryption for user volume..."

  echo "$LUKS_PASSWORD" | cryptsetup luksFormat --batch-mode "$USRVOL_PART"
  echo "$LUKS_PASSWORD" | cryptsetup open "$USRVOL_PART" usrvol
}

# Create btrfs filesystems
create_filesystems() {
  echo "Creating filesystems..."

  # Format EFI partition
  mkfs.fat -F 32 "$EFI_PART"

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
  btrfs subvolume sync /mnt
  sleep 2
  umount /mnt

  # Create user subvolumes
  mount /dev/mapper/usrvol /mnt
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@opt
  btrfs subvolume sync /mnt
  sleep 2
  umount /mnt
}

# Mount all filesystems
mount_filesystems() {
  echo "Mounting filesystems..."

  # Mount root subvolume
  mount -t btrfs -o subvol=@,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt

  # Create mount points
  mkdir -p /mnt/{boot,var,var/{cache,log,tmp},tmp,home,opt,root,.snapshots,.swapvol}

  # Mount system subvolumes
  mount -t btrfs -o subvol=@root,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/root
  mount -t btrfs -o subvol=@var,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var
  mount -t btrfs -o subvol=@var/cache,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var/cache
  mount -t btrfs -o subvol=@var/log,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var/log
  mount -t btrfs -o subvol=@var/tmp,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/var/tmp
  mount -t btrfs -o subvol=@tmp,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/tmp
  mount -t btrfs -o subvol=@snapshots,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/.snapshots
  mount -t btrfs -o subvol=@swap,"$BTRFS_OPTS" "$SYSVOL_PART" /mnt/.swapvol

  # Mount user subvolumes
  mount -t btrfs -o subvol=@home,"$BTRFS_OPTS" /dev/mapper/usrvol /mnt/home
  mount -t btrfs -o subvol=@opt,"$BTRFS_OPTS" /dev/mapper/usrvol /mnt/opt

  # Mount EFI partition
  mount "$EFI_PART" /mnt/boot

  echo "Filesystem layout:"
  lsblk
  sleep 5
}
