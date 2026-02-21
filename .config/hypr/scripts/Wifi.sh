#!/usr/bin/env bash
# Rofi-based WiFi manager using nmcli

rofi_theme="$HOME/.config/rofi/config-wifi.rasi"

# Kill rofi if already running
if pidof rofi > /dev/null; then
    pkill rofi
    exit 0
fi

# Signal strength to icon
signal_icon() {
    local signal=$1
    if (( signal >= 80 )); then echo "󰤨"
    elif (( signal >= 60 )); then echo "󰤥"
    elif (( signal >= 40 )); then echo "󰤢"
    elif (( signal >= 20 )); then echo "󰤟"
    else echo "󰤯"
    fi
}

# Show a rofi menu and return selection
show_menu() {
    local mesg="$1"
    shift
    echo -e "$@" | rofi -i -dmenu -config "$rofi_theme" -mesg "$mesg"
}

# Get current connection info
get_current() {
    nmcli -t -f NAME,TYPE,DEVICE con show --active 2>/dev/null | grep ":802-11-wireless:" | cut -d: -f1
}

# Check if wifi is enabled
wifi_enabled() {
    nmcli radio wifi 2>/dev/null | grep -q "enabled"
}

# Get list of known (saved) SSIDs
get_known_ssids() {
    nmcli -t -f NAME,TYPE con show 2>/dev/null | grep ":802-11-wireless$" | cut -d: -f1
}

# Scan and build network list
get_networks() {
    local current="$1"
    local known_ssids
    known_ssids=$(get_known_ssids)

    nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list --rescan "$2" 2>/dev/null | \
        sort -t: -k2 -rn | \
        awk -F: '!seen[$1]++ && $1 != ""' | \
        while IFS=: read -r ssid signal security; do
            local icon
            icon=$(signal_icon "$signal")
            local lock=""
            [[ -n "$security" && "$security" != "--" ]] && lock="󰌾 "

            local tag=""
            if [[ "$ssid" == "$current" ]]; then
                tag="  connected"
            elif echo "$known_ssids" | grep -qxF "$ssid"; then
                tag="  saved"
            fi

            echo "$icon  ${lock}${ssid}${tag}|$ssid|$signal|$security"
        done
}

# Password prompt
ask_password() {
    local ssid="$1"
    rofi -dmenu -password -config "$rofi_theme" -mesg "󰌾  Password for $ssid"
}

# Connect to a network
connect_to() {
    local ssid="$1"
    local known_ssids
    known_ssids=$(get_known_ssids)

    if echo "$known_ssids" | grep -qxF "$ssid"; then
        # Known network — just activate
        notify-send "Wi-Fi" "Connecting to $ssid..." -i network-wireless -t 3000
        if nmcli con up "$ssid" 2>&1 | grep -q "successfully activated"; then
            notify-send "Wi-Fi" "Connected to $ssid" -i network-wireless
        else
            notify-send "Wi-Fi" "Failed to connect to $ssid" -i network-wireless -u critical
        fi
    else
        # New network — need password
        local pass
        pass=$(ask_password "$ssid")
        [[ -z "$pass" ]] && return

        notify-send "Wi-Fi" "Connecting to $ssid..." -i network-wireless -t 3000
        if nmcli dev wifi connect "$ssid" password "$pass" 2>&1 | grep -q "successfully activated"; then
            notify-send "Wi-Fi" "Connected to $ssid" -i network-wireless
        else
            notify-send "Wi-Fi" "Failed to connect to $ssid" -i network-wireless -u critical
        fi
    fi
}

# Scan flow — stays open with refreshing results
scan_and_show() {
    local current
    current=$(get_current)

    local attempt
    for attempt in 1 2 3; do
        local rescan="no"
        [[ $attempt -eq 1 ]] && rescan="yes"

        local networks
        networks=$(get_networks "$current" "$rescan")

        local menu=""
        if [[ -n "$networks" ]]; then
            menu+="$networks\n"
        fi

        if [[ $attempt -lt 3 ]]; then
            menu+="󰑐  Rescan|rescan|0|"
        else
            menu+="󰄬  Done|done|0|"
        fi

        local choice
        choice=$(echo -e "$menu" | cut -d'|' -f1 | rofi -i -dmenu -config "$rofi_theme" -mesg "󰤨  Networks")

        [[ -z "$choice" ]] && return

        case "$choice" in
            *"Rescan"*) continue ;;
            *"Done"*) return ;;
            *)
                local selected_line
                selected_line=$(echo -e "$menu" | grep -F "${choice}|")
                local ssid
                ssid=$(echo "$selected_line" | cut -d'|' -f2)
                connect_to "$ssid"
                return
                ;;
        esac
    done
}

# Main
main() {
    while true; do
        if ! wifi_enabled; then
            local choice
            choice=$(show_menu "󰤭  Wi-Fi is off" "󰤨  Turn on")
            case "$choice" in
                *"Turn on"*)
                    nmcli radio wifi on
                    notify-send "Wi-Fi" "Turned on" -i network-wireless
                    sleep 1
                    continue
                    ;;
                *) exit 0 ;;
            esac
        fi

        local current
        current=$(get_current)

        local menu=""

        # Current connection
        if [[ -n "$current" ]]; then
            local signal
            signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list 2>/dev/null | grep '^\*' | cut -d: -f2 | head -1)
            local icon
            icon=$(signal_icon "${signal:-0}")
            menu+="$icon  $current  connected\n"
            menu+="󰤮  Disconnect\n"
        fi

        menu+="󰑐  Scan for networks\n"
        menu+="󰤭  Wi-Fi off"

        local choice
        choice=$(show_menu "󰤨  Wi-Fi" "$menu")

        case "$choice" in
            "") exit 0 ;;
            *"Disconnect"*)
                nmcli con down "$current" > /dev/null 2>&1
                notify-send "Wi-Fi" "Disconnected from $current" -i network-wireless
                continue
                ;;
            *"Scan"*)
                scan_and_show
                exit 0
                ;;
            *"Wi-Fi off"*)
                nmcli radio wifi off
                notify-send "Wi-Fi" "Turned off" -i network-wireless
                exit 0
                ;;
            *"connected"*)
                # Clicked on current network — do nothing, re-show
                continue
                ;;
            *) exit 0 ;;
        esac
    done
}

main
