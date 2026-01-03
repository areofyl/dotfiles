#!/bin/bash
# Animated Asahi Linux ASCII Logo

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
GRAY='\033[1;90m'

# Hide cursor during animation
tput civis
trap 'tput cnorm' EXIT

clear

# Asahi leaf logo - line by line reveal
declare -a LOGO=(
"           ${GREEN}##${YELLOW}  **${R}"
"               ${GREEN}*####${YELLOW}****.${R}"
"                 ${GREEN}###${YELLOW},${R}"
"              ${GREEN}...${YELLOW},/${GREEN}#${YELLOW},,,.."
"         ${GREEN}/*,,,,,,,,${YELLOW}*${YELLOW},........,,${R}"
"       ${GREEN},((((((//*${YELLOW},,,,,,,,,......${R}"
"      ${GREEN}((((((((((((((%${YELLOW}............${R}"
"    ${GREEN},(((((((((((((((${CYAN}@@${YELLOW}(............${R}"
"   ${GREEN}(((((((((((((((((${CYAN}@@@@${YELLOW}/............${R}"
" ${GREEN},(((((((((((((((((${CYAN}(@@@@@${BLUE}&${YELLOW}*...........${R}"
"${GREEN}(((((((((((((((((((${CYAN}(@@@@@@@${BLUE}&${YELLOW},...........${R}"
"${GREEN}((((((((((((((((((((${CYAN}@@@${BLUE}&%&${CYAN}@@@${BLUE}%${YELLOW},..........${R}"
"${GREEN} /((((((((((((((((((${CYAN}@@@${BLUE}&%%&${CYAN}@@@@${YELLOW}(........${R}"
"${GREEN}    ,(((((((((((((((${CYAN}@@@${BLUE}&&${CYAN}@@&${BLUE}/&${CYAN}@@@${YELLOW}/..${R}"
"${GREEN}        /((((((((((((${CYAN}@@@@@@${YELLOW}/.../&&${R}"
"${GREEN}           .(((((((((${CYAN}@@@@${YELLOW}(....${R}"
"${GREEN}               /(((((${CYAN}@@${BLUE}#${YELLOW}...${R}"
"${GREEN}                  .((${BLUE}&${YELLOW},${R}"
)

# Animation: Grow the leaf from bottom to top
animate_grow() {
    local total=${#LOGO[@]}

    for ((i=total-1; i>=0; i--)); do
        clear
        echo ""

        # Print lines from i to end
        for ((j=i; j<total; j++)); do
            echo -e "${LOGO[$j]}"
        done

        sleep 0.045
    done
}

# Shimmer effect on the logo
shimmer_logo() {
    for ((s=0; s<2; s++)); do
        # Bright flash
        clear
        echo ""
        echo -e "           ${WHITE}##${WHITE}  **${R}"
        echo -e "               ${WHITE}*####${WHITE}****.${R}"
        echo -e "                 ${GREEN}###${YELLOW},${R}"
        for ((i=3; i<${#LOGO[@]}; i++)); do
            echo -e "${LOGO[$i]}"
        done
        sleep 0.08

        # Normal
        clear
        echo ""
        for line in "${LOGO[@]}"; do
            echo -e "$line"
        done
        sleep 0.08
    done
}

# Typing effect
type_text() {
    local text="$1"
    local color="$2"
    for ((i=0; i<${#text}; i++)); do
        echo -ne "${color}${text:$i:1}${R}"
        sleep 0.015
    done
    echo ""
}

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

# Get network - removed, now shown in waybar instead

# Main animation
main() {
    # Grow animation
    animate_grow

    # Full logo
    clear
    echo ""
    for line in "${LOGO[@]}"; do
        echo -e "$line"
    done
    sleep 0.1

    # Shimmer effect
    shimmer_logo

    # Final display
    clear
    echo ""
    for line in "${LOGO[@]}"; do
        echo -e "$line"
    done

    echo ""
    echo -e "${DIM}───────────────────────────────────────────${R}"
    type_text "        F E D O R A   A S A H I   R E M I X" "${ORANGE}"
    echo -e "${DIM}───────────────────────────────────────────${R}"
    echo ""

    # System info with staggered reveal
    sleep 0.05
    echo -e "  ${CYAN}󰌢${WHITE}  Apple M1 MacBook Air${R}"
    sleep 0.03
    echo -e "  ${YELLOW}${WHITE}  $(uname -r | cut -d'-' -f1-2)${R}"
    sleep 0.03
    echo -e "  ${BLUE}${WHITE}  Hyprland${R}"
    sleep 0.03
    echo -e "  ${MAGENTA}󰍛${WHITE}  $(free -h | awk '/^Mem:/ {print $3 " / " $2}')${R}"
    sleep 0.03
    echo -e "  ${GREEN}󰋊${WHITE}  $(get_disk)${R}"
    sleep 0.03
    echo -e "  ${YELLOW}$(get_battery)${R}"
    sleep 0.03
    echo -e "  ${RED}󱃂${WHITE}  $(get_temp)${R}"
    echo ""
    echo -e "  ${RED}  ${ORANGE}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${WHITE} ${R}"
    echo ""
}

main
tput cnorm
