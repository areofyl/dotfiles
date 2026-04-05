#!/bin/sh
# Launch custom lock screen for DWL
pkill -f "lockscreen.py" 2>/dev/null
LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so python3 ~/.config/custom-lock/lockscreen.py
