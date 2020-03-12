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
	echo -e "${RED}-------------------------------------------------"
	echo -e "${NC}\t--==[ arch-installer v0.1.0 ]==--"
	echo -e "${RED}-------------------------------------------------\n"
}


main()
{
	clear
	print_header
	welcome_message
}

main