#!/bin/sh
# Launch custom lock screen for DWL
# Skip if already locked (avoids swayidle re-triggering a second instance)
[ -f /tmp/dwl-locked ] && exit 0

touch /tmp/dwl-locked
# Restart the lockscreen if it crashes — only the lockscreen itself
# removes the flag on successful auth, so a crash loops back.
# Runs in a subshell so this script returns immediately (needed for
# swayidle before-sleep to release its inhibitor without blocking).
(while [ -f /tmp/dwl-locked ]; do
    LD_PRELOAD=/usr/lib64/libgtk4-layer-shell.so python3 ~/.config/custom-lock/lockscreen.py
    [ -f /tmp/dwl-locked ] && sleep 0.5
done) &
# Give the lockscreen a moment to grab the overlay layer before we return
sleep 0.4
