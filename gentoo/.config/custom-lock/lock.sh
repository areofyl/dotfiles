#!/bin/sh
# Launch custom lock screen for DWL
# Restart the lockscreen if it crashes — only the lockscreen itself
# removes the flag on successful auth, so a crash loops back.
pkill -f "lockscreen.py" 2>/dev/null
touch /tmp/dwl-locked
while [ -f /tmp/dwl-locked ]; do
    LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so python3 ~/.config/custom-lock/lockscreen.py
    [ -f /tmp/dwl-locked ] && sleep 0.5
done
