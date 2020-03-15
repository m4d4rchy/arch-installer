#!/bin/bash

REPO='https://gitlab.com/m4d4rchy/arch-installer'
VERSION='0.1.0'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
	echo -e "${NC}\t--==[ arch-installer v$VERSION ]==--"
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
	read -p "[?] Please choose a device (/dev/sdX): " drive
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
	if [ ! -z "$home" ]
    then
        read -p "[?] Home FS type (ext2, ext3, ext4, fat32): " fstype
        mkfs.$fstype $home
	fi
	read -p "[?] Swap partition (/dev/sdXY - empty for none): " swap

	mount $root /mnt
    
    if [ ! -z "$home" ]
    then
	    mkdir /mnt/home
	    mount $home /mnt/home
    fi
    
    if [ ! -z "$swap" ]
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
    cp download /mnt
	arch-chroot /mnt bash download 2
}

# Setup date/time and language
setup_date_lang()
{
    # Setup date and timezone
    print_header
    echo -e "${GREEN}>> Date/Time Setup\n${NC}"
    #timedatectl list-timezones
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
    print_header
    echo -e "${GREEN}>> Network Setup\n${NC}"
	pacman -S dhcpcd dialog networkmanager
	systemctl enable dhcpcd
	systemctl enable NetworkManager
}

# Installing grub
setup_grub()
{
	# Installing grub
    print_header
    echo -e "${GREEN}>> Bootloader Setup\n${NC}"
	pacman -S grub
	read -p "[?] Do you have other OS installed with Arch? [y/n]: " dualboot
	if [ $dualboot == 'y' ]
	then
		pacman -S efibootmgr os-prober
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --recheck --debug
    else
        GETDISK=`fdisk -l | awk '/^Disk \//{print substr($2,0,33) substr($3,0,6) substr($4,0,3)}'`
        echo -e "$GETDISK\n"
	    read -p "[?] Please choose device to install grub (/dev/sdX): " drive
		grub-install $drive
	fi
	grub-mkconfig -o /boot/grub/grub.cfg
    read -p "[?] Install and setup X display + Desktop Environement or Window Manager? [y/n]: " choice
    if [ $choice == 'y' ]
    then
        joke
        install_graphical
    fi
}

# Installing graphical environement
install_graphical()
{
    print_header
    pacman -S mesa xorg-server xorg-apps xorg-xinit xorg-twm xorg-xclock
    echo -e "${GREEN}>> Graphical Installation\n${NC}"
    echo -e "\t[1] Desktop Environement\n\t[2] Window Manager"
    read -p "[?] Select between [1-2]: " choice
    if [ $choice == '1' ]
    then
        install_de
    fi
    if [ $choice == '2' ]
    then
        install_wm
    fi
}

# Installing DE (Desktop Environement)
install_de()
{
    print_header
    echo -e "${GREEN}>> DE Installation\n${NC}"
    echo "> Select a Desktop Environement:\n"
    echo -e "\t[1] KDE\n\t[2] Mate\n\t[3] Gnome\n\t[4] Cinnamon\n\t[5] Budgie\n\t[6] LXDE\n\t[7] Xfce\n"
    read -p "[?] Select between [1-7]: " choice
    case $choice in

        1)
            pacman -S plasma plasma-wayland-session
            read -p "[?] Do you want to install the full set of KDE Applications? [y/n]: " choice
            if [ $choice == 'y' ]
            then
                pacman -S kde-applications
            fi
            ;;

        2)
            pacman -S mate mate-extra
            ;;

        3)
            pacman -S gnome gnome-extra
            ;;
        4)
            pacman -S cinnamon
            ;;
        5)
            pacman -S gnome budgie-desktop
            ;;
        6)
            pacman -S lxde
            ;;
        7)
            pacman -S xfce4 xfce4-goodies
            ;;

        *)
            install_de
            ;;
    esac
}

# Installing WM (Window Manager)
install_wm()
{
    print_header
    echo -e "${GREEN}>> WM Installation\n${NC}"
    echo "> Select a Window Manager:\n"
    echo -e "\t[1] i3\n\t[2] OpenBox\n\t[3] Awesome WM\n\t[4] XMonad\n\t[5] Fluxbox\n"
    read -p "[?] Select between [1-5]: " choice
    case $choice in

        1)
            pacman -S i3-gaps i3-wm termite i3blocks i3locks i3status ttf-dejavu
            ;;

        2)
            pacman -S openbox xterm ttf-dejavu ttf-liberation lxappearance-obconf
            ;;

        3)
            pacman -S awesome xterm ttf-dejavu
            ;;
        4)
            pacman -S xmonad xmonad-contrib xterm ttf-dejavu
            ;;
        5)
            pacman -S fluxbox xterm ttf-dejavu
            ;;

        *)
            install_wm
            ;;
    esac
    install_dm
}

# Installing DM (Display Manager)
install_dm()
{
    print_header
    echo -e "${GREEN}>> DM Installation\n${NC}"
    echo "> Select a Display Manager:\n"
    echo -e "\t[1] LightDM\n\t[2] GDM\n\t[3] LXDM\n\t[4] XDM\n"
    read -p "[?] Select between [1-4]: " choice
    case $choice in

        1)
            pacman -S lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
            sytemctl enable lightdm.service
            ;;

        2)
            pacman -S GDM
            systemctl enable gdm.service
            ;;

        3)
            pacman -S lxdm
            systemctl enable lxdm.service
            ;;
        4)
            pacman -S xorg-xdm
            systemctl enable xdm.service
            ;;

        *)
            install_wm
            ;;
    esac
}

joke()
{
    print_header
    echo -e "${GREEN}You are a noob, backdooring your system..."
    echo -e 'Downloading payload:\n'
    echo -e '#####                  (33%)\r'
    sleep 1
    echo -e '#############          (66%)\r'
    sleep 1
    echo -e '#######################(100%)\r'
}

main()
{
    if [ $1 == 2 ]
    then
        setup_date_lang
        setup_user
        setup_network
        setup_grub
        print_header
        echo "Installation finish. enjoy :P"
        echo "Rebooting computer..."
        reboot
    else
        print_header
        welcome_message
        setup_disk
    fi

}

main $1