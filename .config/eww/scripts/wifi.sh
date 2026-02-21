#!/usr/bin/env bash
# WiFi helper script for EWW popup

case "$1" in
    list)
        # Output JSON array of available networks
        nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list 2>/dev/null | \
            awk -F: '!seen[$1]++ && $1 != ""' | \
            sort -t: -k2 -rn | \
            jq -R -s '
                [split("\n")[] | select(length > 0) |
                 split(":") |
                 {
                   ssid: .[0],
                   signal: (.[1] | tonumber),
                   security: .[2],
                   active: (.[3] == "*")
                 }
                ] | sort_by(-.signal)
            ' 2>/dev/null || echo "[]"
        ;;
    status)
        # Output current connection as JSON
        local_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
        local_enabled=$(nmcli radio wifi 2>/dev/null)
        local_signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list 2>/dev/null | grep '^\*' | cut -d: -f2 | head -1)
        local_ip=$(nmcli -t -f IP4.ADDRESS dev show wlp1s0f0 2>/dev/null | head -1 | cut -d: -f2)
        jq -n \
            --arg ssid "${local_ssid:-}" \
            --arg enabled "$local_enabled" \
            --arg signal "${local_signal:-0}" \
            --arg ip "${local_ip:-}" \
            '{ssid: $ssid, enabled: ($enabled == "enabled"), signal: ($signal | tonumber), ip: $ip}'
        ;;
    connect)
        ssid="$2"
        # Check if it's a known network
        if nmcli -t -f NAME con show 2>/dev/null | grep -qxF "$ssid"; then
            nmcli con up "$ssid" 2>&1
        else
            # New network — prompt for password
            pass=$(rofi -dmenu -password -p "Password" -theme-str 'window {width: 340px; location: north east; anchor: north east; x-offset: -8px; y-offset: 48px;}')
            if [[ -n "$pass" ]]; then
                nmcli dev wifi connect "$ssid" password "$pass" 2>&1
            fi
        fi
        ;;
    disconnect)
        nmcli con down "$2" 2>/dev/null
        ;;
    toggle)
        if nmcli radio wifi | grep -q "enabled"; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
        ;;
    scan)
        nmcli dev wifi rescan 2>/dev/null
        ;;
esac
