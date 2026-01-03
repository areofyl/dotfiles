#!/usr/bin/env bash
# Hacker Mode - cmatrix as background using special workspace

STATE_FILE="$HOME/.cache/hacker-mode-active"
CMATRIX_CLASS="hacker-cmatrix"
SPECIAL_WS="special:matrix"

start_hacker_mode() {
    # Kill any existing cmatrix first
    pkill -f "$CMATRIX_CLASS" 2>/dev/null

    # Clear wallpaper to black
    swww clear 000000 2>/dev/null

    # Launch cmatrix on the special workspace
    hyprctl dispatch exec "[workspace $SPECIAL_WS silent; fullscreen] kitty --class $CMATRIX_CLASS -o background_opacity=1.0 -o font_size=10 -o cursor_shape=block cmatrix -b -u 2 -C green"

    sleep 0.3

    # Show the special workspace (it appears behind regular windows)
    hyprctl dispatch togglespecialworkspace matrix

    touch "$STATE_FILE"
    notify-send -u low -t 1500 "HACKER MODE" "Enabled" 2>/dev/null
}

stop_hacker_mode() {
    # Hide special workspace
    hyprctl dispatch togglespecialworkspace matrix

    # Kill cmatrix
    pkill -f "$CMATRIX_CLASS" 2>/dev/null

    # Restore wallpaper
    swww img ~/Pictures/wallpapers/pixel-rain.gif --transition-type fade 2>/dev/null

    rm -f "$STATE_FILE"
    notify-send -u low -t 1500 "HACKER MODE" "Disabled" 2>/dev/null
}

if [[ -f "$STATE_FILE" ]]; then
    stop_hacker_mode
else
    start_hacker_mode
fi
