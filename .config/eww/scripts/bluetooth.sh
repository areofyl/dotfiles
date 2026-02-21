#!/usr/bin/env bash
# Bluetooth helper script for EWW popup

case "$1" in
    list)
        # Output JSON array of paired devices
        devices="[]"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            mac=$(echo "$line" | awk '{print $2}')
            name=$(echo "$line" | cut -d' ' -f3-)
            connected="false"
            bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && connected="true"
            devices=$(echo "$devices" | jq --arg n "$name" --arg m "$mac" --argjson c "$connected" \
                '. + [{name: $n, mac: $m, connected: $c}]')
        done < <(bluetoothctl devices Paired 2>/dev/null)
        echo "$devices"
        ;;
    status)
        powered="false"
        bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && powered="true"
        # Count connected devices
        count=0
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            mac=$(echo "$line" | awk '{print $2}')
            bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && ((count++))
        done < <(bluetoothctl devices Paired 2>/dev/null)
        jq -n --argjson p "$powered" --argjson c "$count" '{powered: $p, connected_count: $c}'
        ;;
    connect)
        mac="$2"
        name="$3"
        notify-send "Bluetooth" "Connecting to $name..." -i bluetooth -t 3000
        if bluetoothctl connect "$mac" 2>&1 | grep -q "Connection successful"; then
            notify-send "Bluetooth" "Connected to $name" -i bluetooth
        else
            notify-send "Bluetooth" "Failed to connect to $name" -i bluetooth -u critical
        fi
        ;;
    disconnect)
        mac="$2"
        name="$3"
        bluetoothctl disconnect "$mac" > /dev/null 2>&1
        notify-send "Bluetooth" "Disconnected from $name" -i bluetooth
        ;;
    toggle)
        if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
            bluetoothctl power off > /dev/null 2>&1
        else
            bluetoothctl power on > /dev/null 2>&1
        fi
        ;;
    scan)
        bluetoothctl --timeout 5 scan on > /dev/null 2>&1
        ;;
esac
