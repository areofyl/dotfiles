#!/bin/bash
# Custom lock screen launcher

# Kill any existing instance
pkill -f "lockscreen.py" 2>/dev/null

# Pre-generate blurred wallpaper if needed (faster startup)
WALLPAPER="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
BLURRED="/tmp/lockscreen_blurred.png"

if [ -f "$WALLPAPER" ]; then
    if [ ! -f "$BLURRED" ] || [ "$WALLPAPER" -nt "$BLURRED" ]; then
        magick "$WALLPAPER" -resize 1920x1080\> -blur 0x2 -brightness-contrast -5x0 "$BLURRED" 2>/dev/null &
    fi
fi

# Launch lock screen and wait for it to exit
# Note: submap is switched by the keybind before this script runs
env LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so python3 ~/.config/custom-lock/lockscreen.py

# Restore default keybinds after unlock
hyprctl dispatch submap reset
