#!/bin/bash

# Проверка на SSD
if [ -e "/dev/nvme0n1" ]; then
    DISK_DEVICE="/dev/nvme0n1"
    BOOT_PARTITION="${DISK_DEVICE}p1"
    ROOT_PARTITION="${DISK_DEVICE}p2"
else
    DISK_DEVICE="/dev/sda"
    BOOT_PARTITION="${DISK_DEVICE}1"
    ROOT_PARTITION="${DISK_DEVICE}2"
fi

# Разметка диска под UEFI GPT с шифрованием
parted $DISK_DEVICE mklabel gpt
parted $DISK_DEVICE mkpart ESP fat32 1Mib 512Mib
parted $DISK_DEVICE set 1 boot on

parted $DISK_DEVICE mkpart primary 513Mib 100%

# Шифруем раздел
cryptsetup luksFormat $ROOT_PARTITION
echo "YES" | cryptsetup luksFormat $ROOT_PARTITION
cryptsetup open $ROOT_PARTITION luks

# Создаем логические разделы
pvcreate /dev/mapper/luks
vgcreate main /dev/mapper/luks
lvcreate -l 100%FREE main -n root

# Форматируем разделы
mkfs.ext4 /dev/mapper/main-root
mkfs.fat -F 32 $BOOT_PARTITION

# Монтируем разделы
mount /dev/mapper/main-root /mnt
mkdir /mnt/boot
mount $BOOT_PARTITION /mnt/boot

# Устанавливаем базовые пакеты
pacstrap -K /mnt base linux linux-firmware base-devel lvm2 dhcpcd net-tools iproute2 networkmanager vim micro efibootmgr iwd
genfstab -U /mnt >> /mnt/etc/fstab

# Настраиваем систему
arch-chroot /mnt

# Настраиваем локаль
locale-gen
ln -sf /usr/share/zoneinfo/Europe/Kiev /etc/localtime
hwclock --systohc
echo "arch" > /etc/hostname
passwd
useradd -m -G wheel,users -s /bin/bash user
passwd user
systemctl enable dhcpcd
systemctl enable iwd.service

# Пересобираем initramfs
micro /etc/mkinitcpio.conf
mkinitcpio -p linux

# Устанавливаем загрузчик
bootctl install --path=/boot
micro /boot/loader/loader.conf
micro /boot/loader/entries/arch.conf

# Разрешаем пользователю использовать sudo
visudo

# Выходим из системы и перезагружаемся
exit
umount -R /mnt
reboot

