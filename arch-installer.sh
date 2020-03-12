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


}

main()
{
	print_header
	welcome_message
    setup_disk
    #timedatectl set-ntp true
}

main