#!/bin/bash
# Workspace-aware theme switching

WARM_WALLPAPER="$HOME/Pictures/wallpapers/minimal-warm.jpg"
DEFAULT_WALLPAPER="$HOME/Pictures/wallpapers/pixel-rain.gif"

apply_warm_theme() {
    swww img "$WARM_WALLPAPER" \
        --transition-type fade \
        --transition-duration 1.5 \
        --transition-fps 60

    hyprctl keyword general:col.active_border "rgb(c17f59)"
    hyprctl keyword general:col.inactive_border "rgb(252320)"
    hyprctl keyword decoration:rounding 14
    hyprctl keyword general:border_size 1
}

apply_default_theme() {
    swww img "$DEFAULT_WALLPAPER" \
        --transition-type fade \
        --transition-duration 0.8 \
        --transition-fps 60

    hyprctl keyword decoration:rounding 10
    hyprctl keyword general:border_size 2
}

# Simple polling - checks workspace every 0.5s
last_ws=""
while true; do
    current_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null)

    if [ "$current_ws" != "$last_ws" ]; then
        if [ "$current_ws" = "2" ]; then
            apply_warm_theme
        elif [ "$last_ws" = "2" ]; then
            apply_default_theme
        fi
        last_ws="$current_ws"
    fi
    sleep 0.5
done
