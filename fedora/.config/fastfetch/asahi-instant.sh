#!/bin/bash
# Instant Asahi Linux ASCII Logo (no animation)

# Colors
R='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[1;31m'
ORANGE='\033[1;38;5;208m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'

# Get battery info
get_battery() {
    if [ -d /sys/class/power_supply/macsmc-battery ]; then
        local capacity=$(cat /sys/class/power_supply/macsmc-battery/capacity 2>/dev/null)
        local status=$(cat /sys/class/power_supply/macsmc-battery/status 2>/dev/null)
        local icon=""

        if [ "$status" = "Charging" ]; then
            icon="󰂄"
        elif [ "$capacity" -ge 90 ]; then
            icon="󰁹"
        elif [ "$capacity" -ge 70 ]; then
            icon="󰂀"
        elif [ "$capacity" -ge 50 ]; then
            icon="󰁾"
        elif [ "$capacity" -ge 30 ]; then
            icon="󰁼"
        elif [ "$capacity" -ge 10 ]; then
            icon="󰁺"
        else
            icon="󰂃"
        fi
        echo "$icon $capacity%"
    else
        echo "󰂃 N/A"
    fi
}

# Get CPU temp
get_temp() {
    local temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
    if [ -n "$temp" ]; then
        echo "$((temp / 1000))°C"
    else
        echo "N/A"
    fi
}

# Get disk usage
get_disk() {
    df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}'
}

# Display everything instantly
clear
echo ""
echo -e "           ${GREEN}##${YELLOW}  **${R}"
echo -e "               ${GREEN}*####${YELLOW}****.${R}"
echo -e "                 ${GREEN}###${YELLOW},${R}"
echo -e "              ${GREEN}...${YELLOW},/${GREEN}#${YELLOW},,,.."
echo -e "         ${GREEN}/*,,,,,,,,${YELLOW}*${YELLOW},........,,${R}"
echo -e "       ${GREEN},((((((//*${YELLOW},,,,,,,,,......${R}"
echo -e "      ${GREEN}((((((((((((((%${YELLOW}............${R}"
echo -e "    ${GREEN},(((((((((((((((${CYAN}@@${YELLOW}(............${R}"
echo -e "   ${GREEN}(((((((((((((((((${CYAN}@@@@${YELLOW}/............${R}"
echo -e " ${GREEN},(((((((((((((((((${CYAN}(@@@@@${BLUE}&${YELLOW}*...........${R}"
echo -e "${GREEN}(((((((((((((((((((${CYAN}(@@@@@@@${BLUE}&${YELLOW},...........${R}"
echo -e "${GREEN}((((((((((((((((((((${CYAN}@@@${BLUE}&%&${CYAN}@@@${BLUE}%${YELLOW},..........${R}"
echo -e "${GREEN} /((((((((((((((((((${CYAN}@@@${BLUE}&%%&${CYAN}@@@@${YELLOW}(........${R}"
echo -e "${GREEN}    ,(((((((((((((((${CYAN}@@@${BLUE}&&${CYAN}@@&${BLUE}/&${CYAN}@@@${YELLOW}/..${R}"
echo -e "${GREEN}        /((((((((((((${CYAN}@@@@@@${YELLOW}/.../&&${R}"
echo -e "${GREEN}           .(((((((((${CYAN}@@@@${YELLOW}(....${R}"
echo -e "${GREEN}               /(((((${CYAN}@@${BLUE}#${YELLOW}...${R}"
echo -e "${GREEN}                  .((${BLUE}&${YELLOW},${R}"

echo ""
echo -e "${DIM}───────────────────────────────────────────${R}"
echo -e "      ${ORANGE}F E D O R A   A S A H I   R E M I X${R}"
echo -e "${DIM}───────────────────────────────────────────${R}"
echo ""

echo -e "  ${CYAN}󰌢${WHITE}  Apple M1 MacBook Air${R}"
echo -e "  ${YELLOW}${WHITE}  $(uname -r | cut -d'-' -f1-2)${R}"
echo -e "  ${BLUE}${WHITE}  Hyprland${R}"
echo -e "  ${MAGENTA}󰍛${WHITE}  $(free -h | awk '/^Mem:/ {print $3 " / " $2}')${R}"
echo -e "  ${GREEN}󰋊${WHITE}  $(get_disk)${R}"
echo -e "  ${YELLOW}$(get_battery)${R}"
echo -e "  ${RED}󱃂${WHITE}  $(get_temp)${R}"
echo ""
echo -e "  ${RED}  ${ORANGE}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${WHITE} ${R}"
echo ""
