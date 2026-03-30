#!/usr/bin/env bash
# Rofi-based Bluetooth manager using bluetoothctl

rofi_theme="$HOME/.config/rofi/config-bluetooth.rasi"

# Kill rofi if already running
if pidof rofi > /dev/null; then
    pkill rofi
    exit 0
fi

# Get bluetooth power state
get_power_state() {
    bluetoothctl show | grep -q "Powered: yes" && echo "on" || echo "off"
}

# Get list of paired devices with connection status
get_devices() {
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            echo "󰂱  $name|$mac|connected"
        else
            echo "󰂯  $name|$mac|paired"
        fi
    done < <(bluetoothctl devices Paired 2>/dev/null)
}

# Show a rofi menu and return selection
show_menu() {
    local mesg="$1"
    shift
    echo -e "$@" | cut -d'|' -f1 | rofi -i -dmenu -config "$rofi_theme" -mesg "$mesg"
}

# Device action submenu
device_action() {
    local name="$1"
    local mac="$2"
    local state="$3"
    local options

    if [[ "$state" == "connected" ]]; then
        options="󰂲  Disconnect\n󰆴  Remove"
    else
        options="󰂱  Connect\n󰆴  Remove"
    fi

    local choice
    choice=$(show_menu "  $name" "$options")

    case "$choice" in
        *"Connect"*)
            notify-send "Bluetooth" "Connecting to $name..." -i bluetooth -t 3000
            if bluetoothctl connect "$mac" 2>&1 | grep -q "Connection successful"; then
                notify-send "Bluetooth" "Connected to $name" -i bluetooth
            else
                notify-send "Bluetooth" "Failed to connect to $name" -i bluetooth -u critical
            fi
            ;;
        *"Disconnect"*)
            bluetoothctl disconnect "$mac" > /dev/null 2>&1
            notify-send "Bluetooth" "Disconnected from $name" -i bluetooth
            ;;
        *"Remove"*)
            bluetoothctl remove "$mac" > /dev/null 2>&1
            notify-send "Bluetooth" "Removed $name" -i bluetooth
            ;;
    esac
}

# Scan and show discovered devices inline
scan_and_show() {
    # Start scan in background
    bluetoothctl scan on &>/dev/null &
    local scan_pid=$!

    # Show "scanning" menu that refreshes
    local attempt
    for attempt in 1 2 3; do
        sleep 2

        local devices=""
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            mac=$(echo "$line" | awk '{print $2}')
            name=$(echo "$line" | cut -d' ' -f3-)
            [[ "$name" == "$mac" ]] && continue
            if bluetoothctl devices Paired 2>/dev/null | grep -q "$mac"; then
                devices+="󰂱  $name  (paired)|$mac|paired\n"
            else
                devices+="󰂯  $name|$mac|new\n"
            fi
        done < <(bluetoothctl devices 2>/dev/null)

        # Build menu
        local menu=""
        if [[ -n "$devices" ]]; then
            menu+="$devices"
        fi
        menu+="󰑐  Keep scanning...|rescan|action"

        if [[ $attempt -eq 3 ]]; then
            # Last round — replace "keep scanning" with "done"
            menu=$(echo -e "$menu" | sed 's/󰑐  Keep scanning.../󰄬  Done/')
        fi

        local secs=$(( attempt * 2 ))
        local choice
        choice=$(echo -e "$menu" | cut -d'|' -f1 | rofi -i -dmenu -config "$rofi_theme" -mesg "󰑐  Scanning...  (${secs}s)")

        [[ -z "$choice" ]] && break

        case "$choice" in
            *"Keep scanning"*) continue ;;
            *"Done"*) break ;;
            *)
                # Device selected
                kill "$scan_pid" 2>/dev/null
                bluetoothctl scan off &>/dev/null

                local selected_line
                selected_line=$(echo -e "$menu" | grep -F "${choice}|")
                local mac state name
                mac=$(echo "$selected_line" | cut -d'|' -f2)
                state=$(echo "$selected_line" | cut -d'|' -f3)
                name=$(echo "$choice" | sed 's/^[^ ]* *//' | sed 's/  (paired)$//')

                if [[ "$state" == "new" ]]; then
                    notify-send "Bluetooth" "Pairing with $name..." -i bluetooth -t 3000
                    bluetoothctl trust "$mac" > /dev/null 2>&1
                    if bluetoothctl pair "$mac" 2>&1 | grep -q "Pairing successful"; then
                        notify-send "Bluetooth" "Paired. Connecting..." -i bluetooth -t 2000
                        bluetoothctl connect "$mac" > /dev/null 2>&1
                    else
                        notify-send "Bluetooth" "Failed to pair with $name" -i bluetooth -u critical
                    fi
                else
                    device_action "$name" "$mac" "paired"
                fi
                return
                ;;
        esac
    done

    kill "$scan_pid" 2>/dev/null
    bluetoothctl scan off &>/dev/null
}

# Main loop
main() {
    while true; do
        local power_state
        power_state=$(get_power_state)

        local menu=""
        if [[ "$power_state" == "on" ]]; then
            menu+="󰑐  Scan for devices|scan|action\n"
            local devices
            devices=$(get_devices)
            if [[ -n "$devices" ]]; then
                menu+="$devices\n"
            fi
            menu+="  Power off|poweroff|action"
        else
            menu="  Power on|poweron|action"
        fi

        local choice
        choice=$(echo -e "$menu" | cut -d'|' -f1 | rofi -i -dmenu -config "$rofi_theme" -mesg "󰂯  Bluetooth")

        case "$choice" in
            "") exit 0 ;;
            *"Power on"*)
                bluetoothctl power on > /dev/null 2>&1
                notify-send "Bluetooth" "Powered on" -i bluetooth
                sleep 0.5
                continue
                ;;
            *"Power off"*)
                bluetoothctl power off > /dev/null 2>&1
                notify-send "Bluetooth" "Powered off" -i bluetooth
                exit 0
                ;;
            *"Scan"*)
                scan_and_show
                exit 0
                ;;
            *)
                local selected_line
                selected_line=$(echo -e "$menu" | grep -F "${choice}|")
                local mac state name
                mac=$(echo "$selected_line" | cut -d'|' -f2)
                state=$(echo "$selected_line" | cut -d'|' -f3)
                name=$(echo "$choice" | sed 's/^[^ ]* *//')
                device_action "$name" "$mac" "$state"
                exit 0
                ;;
        esac
    done
}

main
