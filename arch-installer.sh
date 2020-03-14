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
	cfdisk $drive

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
        cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat $partition
        read -p "[?] Partition name? (default: home): " choice
        choice=${choice:-home}
        cryptsetup luksOpen $partition $choice 
	fi
	
    # Partition file system and mount
    print_header
    echo -e "${GREEN}>> Hard Drive Setup\n${NC}"
    read -p "[?] Do you want Dual Boot? [y/n]: " dualboot
    dualboot=${dualboot:-y}
    echo -e "\n" && fdisk -l | awk '/^\/dev*/' && echo -e "\n"
    blkid | grep /dev/mapper/ && echo -e "\n" #List encrypted partitions
    if [ $dualboot == 'y' ]
    then
        read -p "[?] Boot efi partition (/dev/sdXY): " boot
    fi
	read -p "[?] Root partition (/dev/sdXY): " root
	read -p "[?] Root FS type (ext2, ext3, ext4, fat32): " fstype
	mkfs.$fstype $root
	read -p "[?] Home partition (/dev/sdXY - empty for none): " home
	read -p "[?] Home FS type (ext2, ext3, ext4, fat32): " fstype
	mkfs.$fstype $home
	read -p "[?] Swap partition (/dev/sdXY - empty for none): " swap

	mount $root /mnt
    
    if [!-z "$home"]
    then
	    mkdir /mnt/home
	    mount $home /mnt/home
    fi
    
    if [!-z "$swap"]
    then
        mkswap $swap
        swapon $swap
    fi
	
    pacstrap /mnt base linux linux-firmware
    if [ $dualboot == 'y' ]
    then
        mkdir /mnt/boot/efi
	    mount $boot /mnt/boot/efi
    fi
	genfstab -U /mnt >> /mnt/etc/fstab
	arch-chroot /mnt
}

# Setup date/time and language
setup_date_lang()
{
    # Setup date and timezone
    print_header
    echo -e "${GREEN}>> Date/Time Setup\n${NC}"
    timedatectl list-timezones
    read -p "[?] Select your timezone (Zone/SubZone): " zone
	ln -sf /usr/share/zoneinfo/$zone /etc/localtime
	hwclock --systohc
	date
    read -p "[?] Is your date and time correct? [y/n]: " choice
    choice=${choice:-y}
	if [ $choice == 'n' ]
	then
		setup_date_lang
	fi

    # Setup language
    print_header
    echo -e "${GREEN}>> Language Setup\n${NC}"
	pacman -S vim
	vim /etc/locale.gen
	locale-gen
	echo -e ">> Language Setup\n\n"
	read -p "[?] Set language [en_GB.UTF-8]: " language
	echo "LANG=$language" >> /etc/locale.conf
	read -p "[?] Set keymap [fr-latin1]: " keymap
	echo "KEYMAP=$keymap" >> /etc/vconsole.conf
}

# Setup User and hostname
setup_user()
{
    # Setup hostname
    print_header
    echo -e "${GREEN}>> Hostname Setup\n${NC}"
	read -p "[?] Set hostname: " hostname
	echo "$hostname" > /etc/hostname
	echo -e "\n127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$hostname.localdomain $hostname" >> /etc/hosts

    # Installing and config sudo
    pacman -S sudo
	visudo

    # Setup root and user account
    print_header
    echo -e "${GREEN}>> User/Root Setup\n${NC}"
    echo "[?] Set root password"
	passwd
	read -p "[?] Set username: " username
	useradd -m $username
	passwd $username
	usermod -aG wheel,audio,video,optical,storage $username
    echo "[+] $username's groups:"
	groups $username

}

# Setup Networking
setup_network()
{
	pacman -S dhcpcd networkmanager 
	systemctl enable dhcpcd
	sudo systemctl enable NetworkManager
	read -p "[?] Install wifi (dialog & wpa_supplicant)? [y/n]: " choice
    choice=${choice:-y}
	if [ $choice == 'y' ]
	then
		sudo pacman -S dialog wpa_supplicant
	fi
}

main()
{
	print_header
	welcome_message
    timedatectl set-ntp true
    setup_disk
    setup_date_lang
    setup_user
}

main