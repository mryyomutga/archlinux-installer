#!/bin/bash

# Check boot mode
if ! [[ -d /sys/firmware/efi/efivars ]]; then
  echo "UEFI mode is disabled."
  exit 1
fi

# Check Internet connection
if ! ping -c 3 archlinux.org > /dev/null 2>&1; then
  echo "No connection is available."
  exit 1
fi

# Set default values
read -e -p 'username:' -i mryyomutga username
read -e -p 'block device:' -i sda block_device
read -e -p 'partition 1:' -i sda1 partitions[0]
read -e -p 'partition 2:' -i sda2 partitions[1]

# Set password
read -s -p 'root password:' password["root"]
read -s -p "$username password:" password["$username"]

# Update the system clock
timedatectl set-ntp true

# Partition the disks
#
# | Mount point | Partition       | Partition Type | Filesystem | Size  |
# |:------------|:----------------|:---------------|:-----------|:------|
# | /boot       | ${partition[0]} | EFI System     | FAT32      | 512MB |
# | /           | ${partition[1]} | Linux LVM      | ext4       | 30GB  |
# | /home       | ${partition[1]} | Linux LVM      | ext4       | rest  |

# Create partitions
sgdisk -Z /dev/$block_device
sgdisk -n 0::+100M -t 0:EF00 -c 0:'EFI System' /dev/$block_device
sgdisk -n 0::: -t 0:8E00 -c 0:'Linux LVM' /dev/$block_device
sgdisk -p /dev/$block_device

## Create physical volumes
pvcreate /dev/${partitions[1]}

## Create volume group
vgcreate vg00 /dev/${partitions[1]}

## Create logical volumes
lvcreate -y vg00 -L 30GB -n root
lvcreate -y vg00 -l 100%FREE -n home

# Format the filesystem
# mkfs.vfat -F 32 /dev/${patitions[0]}
# mkfs.ext4 /dev/${partitions[1]}
mkfs.vfat -F 32 /dev/${partitions[0]}
mkfs.ext4 /dev/mapper/vg00-root
mkfs.ext4 /dev/mapper/vg00-home

# Mount the filesystem
# mount /dev/${partitions[1]} /mnt
# mkdir -p /mnt/boot
# mount /dev/${partitions[0]} /mnt/boot
mount /dev/mapper/vg00-root /mnt
mkdir -p /{boot,home}
mount /dev/maper/vg00-home /mnt/home
mount /dev/${partitions[0]} /mnt/boot

# Force a refresh of all package list
pacman -Syy

# Update the latest mirror list
pacman -S --noconfirm reflector
cp /etc/pacman.d/mirrorlist{,.bak}
reflector -c Japan -l 5 -p http --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

# Install the base packages
pacstrap /mnt base base-devel wget

# Configure the system
## fstab
genfstab -U -p /mnt >> /mnt/etc/fstab

## Time zone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
arch-chroot /mnt hwclock -w

## Locale
arch-chroot /mnt sed -i -e "/#en_Us.UTF-8 UTF-8 /s/#//" /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt bash -c "echo LANG=en_US.UTF-8 > /etc/locale.conf"

## Keyboard
arch-chroot /mnt bash -c "echo KEYMAP=jp106 > /etc/vconsole.conf"

## Hostname
arch-chroot /mnt bash -c "echo localhost > /etc/hostname"

## Network configuration
arch-chroot /mnt pacman -S --noconfirm iw wpa_supplicant dialog
### netctl-ifplugd
arch-chroot /mnt pacman -S --noconfirm ifplugd
### netctl-auto
arch-chroot /mnt pacman -S --noconfirm wpa_actiond util-linux

## Initramfs
arch-chroot /mnt mkinitcpio -p linux

## User
arch-chroot /mnt bash -c "echo \"root:${password["root"]}\" | chpasswd"
arch-chroot /mnt pacman -S --noconfirm zsh
arch-chroot /mnt useradd -m -g users -G wheel -s /bin/zsh $username
arch-chroot /mnt bash -c "echo \"$username:${password["$username"]}\" | chpasswd"

## Boot loader
arch-chroot /mnt pacman -S --noconfirm intel-ucode
arch-chroot /mnt bootctl --path=/boot install
arch-chroot /mnt curl -o '/boot/loader/#1' \
  https://raw.githubusercontent.com/mryyomutga/installer/master/etc/loader/{loader.conf}
arch-chroot /mnt curl -o '/boot/loader/entries/#1' \
  https://raw.githubusercontent.com/mryyomutga/installer/master/etc/loader/entries/{arch.conf}

# Unmount the filesystem
umount -R /mnt
