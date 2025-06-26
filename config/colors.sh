# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    colors.sh                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: dlesieur <dlesieur@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/06/26 14:25:21 by dlesieur          #+#    #+#              #
#    Updated: 2025/06/26 14:48:37 by dlesieur         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#!/bin/bash

#check if terminal support colors
if [[ -t 1 ]] & command -v tput > /dev/null 2>&1; then 
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[0;33m'
	BLUE='\033[0;34m'
	MAGENTA='\033[0;35m'
	CYAN='\033[0;36m'
	WHITE='\033[0;37m'
	GRAY='\033[0;90m'
	
	# Bold colors
	BOLD_RED='\033[1;31m'
	BOLD_GREEN='\033[1;32m'
	BOLD_YELLOW='\033[1;33m'
	BOLD_BLUE='\033[1;34m'
	BOLD_MAGENTA='\033[1;35m'
	BOLD_CYAN='\033[1;36m'
	BOLD_WHITE='\033[1;37m'
	
	# Background colors
	BG_RED='\033[41m'
	BG_GREEN='\033[42m'
	BG_YELLOW='\033[43m'
	BG_BLUE='\033[44m'
	BG_MAGENTA='\033[45m'
	BG_CYAN='\033[46m'
	BG_WHITE='\033[47m'
	
	# Text formatting
	BOLD='\033[1m'
	DIM='\033[2m'
	ITALIC='\033[3m'
	UNDERLINE='\033[4m'
	BLINK='\033[5m'
	REVERSE='\033[7m'
	STRIKETHROUGH='\033[9m'
	
	# Reset
	RESET='\033[0m'
	
	# Special symbols with colors
	SUCCESS_SYMBOL="${BOLD_GREEN}✓${RESET}"
	FAILURE_SYMBOL="${BOLD_RED}✗${RESET}"
	WARNING_SYMBOL="${BOLD_YELLOW}⚠${RESET}"
	INFO_SYMBOL="${BOLD_BLUE}ℹ${RESET}"
	LOADING_SYMBOL="${BOLD_CYAN}⟳${RESET}"
	
	# Status indicators
	PASS="${BG_GREEN}${BOLD_WHITE} PASS ${RESET}"
	FAIL="${BG_RED}${BOLD_WHITE} FAIL ${RESET}"
	SKIP="${BG_YELLOW}${BOLD_WHITE} SKIP ${RESET}"
	INFO="${BG_BLUE}${BOLD_WHITE} INFO ${RESET}"
	WARN="${BG_YELLOW}${BOLD_WHITE} WARN ${RESET}"
	
else
	# No color support - use empty strings
	RED=''
	GREEN=''
	YELLOW=''
	BLUE=''
	MAGENTA=''
	CYAN=''
	WHITE=''
	GRAY=''
	
	BOLD_RED=''
	BOLD_GREEN=''
	BOLD_YELLOW=''
	BOLD_BLUE=''
	BOLD_MAGENTA=''
	BOLD_CYAN=''
	BOLD_WHITE=''
	
	BG_RED=''
	BG_GREEN=''
	BG_YELLOW=''
	BG_BLUE=''
	BG_MAGENTA=''
	BG_CYAN=''
	BG_WHITE=''
	
	BOLD=''
	DIM=''
	ITALIC=''
	UNDERLINE=''
	BLINK=''
	REVERSE=''
	STRIKETHROUGH=''
	
	RESET=''
	
	SUCCESS_SYMBOL='[OK]'
	FAILURE_SYMBOL='[FAIL]'
	WARNING_SYMBOL='[WARN]'
	INFO_SYMBOL='[INFO]'
	LOADING_SYMBOL='[...]'
	
	PASS='[PASS]'
	FAIL='[FAIL]'
	SKIP='[SKIP]'
	INFO='[INFO]'
	WARN='[WARN]'
fi

# ========================================================= #
# COLOR UTILITY FUNCTIONS									#
# ========================================================= #

colorize()
{
	local color=$1
	local test=$2
	echo -e "${color} ${test} ${RESET}"
}

colorize_n()
{
	local color=$1
	local test=$2
	echo -ne "${color} ${test} ${RESET}"
}

red()
{
	colorize "${RED}" "$1";
}

green()
{
	colorize "${GREEN}" "$1";
}

yellow()
{
	colorize "${YELLOW}" "$1";
}

blue()
{
	colorize "${BLUE}" "$1";
}

magenta()
{
	colorize "${MAGENTA}" "$1";
}

cyan()
{
	colorize "${CYAN}" "$1";
}

white()
{
	colorize "${WHITE}" "$1";
}

gray()
{
	colorize "${GRAY}" "$1";
}


bold_red()
{
	colorize "${BOLD_RED}" "$1";
}

bold_green()
{
	colorize "${BOLD_GREEN}" "$1";
}

bold_yellow()
{
	colorize "${BOLD_YELLOW}" "$1";
}

bold_blue()
{
	colorize "${BOLD_BLUE}" "$1";
}

bold_magenta()
{
	colorize "${BOLD_MAGENTA}" "$1";
}

bold_cyan()
{
	colorize "${BOLD_CYAN}" "$1";
}

bold_white()
{
	colorize "${BOLD_WHITE}" "$1";
}

separator()
{
	local char="${1:-=}"
	local length="${2:-80}"
	local color="${3:-${GRAY}}"

	printf "${color}"
	printf "%*s" "${length}" | tr ' ' "${char}"
	printf "${RESET}\n"
}

print_header()
{
	local title="$1"
	local color="${2:-${BOLD_CYAN}}"

	echo
	separator "=" 80 "${color}"
	echo -e "${color}${BOLD}${title}${RESET}"
	separator "=" 80 "${color}"
	echo
}

print_section()
{
	local title="$1"
	local color="${2:-${BOLD_BLUE}}"

	echo
	echo -e "${color}${BOLD}${title}${RESET}"
	separator "-" ${#title} "${color}"
}

progress_bar()
{
	local current=$1
	local total=$2
	local width=${3:-50}
	local char=${4:-"█"}
	local empty_char=${5:-"░"}
	local percentage=$(((current / total) * 100))
	local filled=$((current * width / total))
	local empty=$((width - filled))

	printf "\r${BOLD_BLUE}Progress: ${RESET}["
	printf "%*s" "${filled}" | tr ' ' "${char}"
	printf "%*s" "${empty}" | tr ' ' "${empty_char}"
	printf "] ${BOLD_CYAN}%d%%${RESET} (${current}/${total})" "${percentage}"
	if [[ ${current} -eq ${total} ]]; then
		echo
	fi
}