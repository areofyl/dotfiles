#!/usr/bin/env bash
# Simple rofi power dropdown menu

# Toggle - if already open, close it
if pgrep -x rofi > /dev/null; then
    pkill -x rofi
    exit 0
fi

options="  Lock\n  Shutdown\n  Reboot\n󰗼  Logout\n󰒲  Suspend"

chosen=$(echo -e "$options" | rofi -dmenu -p "" -theme ~/.config/rofi/config-power.rasi)

case "$chosen" in
    *Lock)      ~/.config/hypr/scripts/LockScreen.sh ;;
    *Shutdown)  systemctl poweroff ;;
    *Reboot)    systemctl reboot ;;
    *Logout)    hyprctl dispatch exit 0 ;;
    *Suspend)   systemctl suspend ;;
esac
