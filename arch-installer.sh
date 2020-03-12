#!/bin/bash

REPO='https://gitlab.com/m4d4rchy/arch-installer'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Partitions
BOOT='/dev/boot'
ROOT='/dev/root'
HOME='/dev/home'

welcome_message()
{
    echo -e "${GREEN}>> Welcome to the Archlinux installation wizard!\n\n${NC}Repository: $REPO\n${YELLOW}"
	read -p "Press any key to start..."
    echo -e "${NC}"
}

print_header()
{
    clear
	echo -e "${RED}-------------------------------------------------"
	echo -e "${NC}\t--==[ arch-installer v0.1.0 ]==--"
	echo -e "${RED}-------------------------------------------------\n${NC}"
}

# Setup disk
setup_disk()
{
    # Creating partition
    print_header
    GETDISK=`fdisk -l | awk '/^Disk \//{print substr($2,0,33) substr($3,0,6) substr($4,0,3)}'`
	echo -e "${GREEN}>> Hard Drive Setup\n\n${NC}[+] Available hard drives for installation:\n"
	echo -e "$GETDISK\n"
	read -p "[?] Please choose a device (/dev/sdXY): " drive
	cfdisk /dev/$drive

    # Display partition created and ask for confirmation
    print_header
    GETPARTITION=`fdisk -l $drive | awk '/^\/dev*/'`
	echo -e "${GREEN}>> Hard Drive Setup\n\n${NC}[+] Partitions:\n"
    echo -e "$GETPARTITION\n"
	read -p "[?] Edit another hard drive? [y/n]: " choice
    choice=${choice:-y}
	if [ $choice == 'y' ]
	then
		setup_disk
	fi

    # Partition Encryption
    print_header
    echo -e "${GREEN}>> Hard Drive Setup\n${NC}"
	read -p "[?] Full encrypted partition? [y/n]: " choice
    choice=${choice:-y}
    if [ $choice == 'y' ]
	then
        echo -e "\n" && fdisk -l | awk '/^\/dev*/' && echo -e "\n"
		read -p "[?] Select partition to encrypt (/dev/sdXY): " partition 
        read -p "[?] Zero-out partition? [y/n]: " choice
        choice=${choice:-y}
        if [ $choice == 'y' ]
        then
            dd if=/dev/zero of=$partition status=progress
        fi
        cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/$partition
        read -p "[?] Partition name? (default: home): " choice
        choice=${choice:-home}
        cryptsetup luksOpen $partition $choice 
	fi
	
    # Partition file system and mount
    print_header
    echo -e "${GREEN}>> Hard Drive Setup\n${NC}"
    echo -e "\n" && fdisk -l | awk '/^\/dev*/' && echo -e "\n"
	read -p "[?] Root partition (/dev/sdXY): " root
	read -p "[?] Root FS type (ext2, ext3, ext4, fat32): " fstype
	mkfs.$fstype /dev/$root
	read -p "[?] Home partition (/dev/sdXY - empty for none): " home
	read -p "[?] Home FS type (ext2, ext3, ext4, fat32): " fstype
	mkfs.$fstype /dev/$home
	read -p "[?] Swap partition (/dev/sdXY - empty for none): " swap

	mount /dev/$root /mnt
    
    if [!-z "$home"]
    then
	    mkdir /mnt/home
	    mount /dev/$home /mnt/home
    fi
    
    if [!-z "$swap"]
    then
        mkswap /dev/$swap
        swapon /dev/$swap
    fi
	
    '''pacstrap /mnt base linux linux-firmware
	#mkdir /mnt/boot/efi
	#mount /dev/$boot /mnt/boot/efi
	genfstab -U /mnt >> /mnt/etc/fstab
	arch-chroot /mnt'''
}

main()
{
	print_header
	welcome_message
    setup_disk
    #timedatectl set-ntp true
}

main