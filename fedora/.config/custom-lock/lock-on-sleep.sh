#!/bin/bash
# Monitor systemd-logind for lock and sleep signals, then lock the screen.
#
# Listens for:
#   - Session Lock signal  (lid close when HandleLidSwitch=lock, loginctl lock-session)
#   - PrepareForSleep      (system suspend/hibernate)

lock_screen() {
    if ! pgrep -f "lockscreen.py" > /dev/null; then
        ~/.config/custom-lock/lock.sh &
    fi
}

# Find the active graphical session object path
SESSION_PATH=""
while IFS= read -r line; do
    sid=$(echo "$line" | awk '{print $1}')
    stype=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
    if [ "$stype" = "wayland" ] || [ "$stype" = "x11" ]; then
        SESSION_PATH=$(busctl call org.freedesktop.login1 \
            /org/freedesktop/login1 \
            org.freedesktop.login1.Manager \
            GetSession s "$sid" 2>/dev/null | awk '{print $2}' | tr -d '"')
        break
    fi
done < <(loginctl list-sessions --no-legend 2>/dev/null)

if [ -z "$SESSION_PATH" ]; then
    echo "No graphical session found, falling back to PrepareForSleep only"
    SESSION_PATH=""
fi

# Monitor both signals in parallel
(
    # Monitor session Lock signal
    if [ -n "$SESSION_PATH" ]; then
        gdbus monitor --system \
            --dest org.freedesktop.login1 \
            --object-path "$SESSION_PATH" 2>/dev/null | \
        while read -r line; do
            if echo "$line" | grep -q "\.Lock ()"; then
                lock_screen
            fi
        done
    fi
) &

(
    # Monitor system PrepareForSleep signal
    gdbus monitor --system \
        --dest org.freedesktop.login1 \
        --object-path /org/freedesktop/login1 2>/dev/null | \
    while read -r line; do
        if echo "$line" | grep -q "PrepareForSleep (true)"; then
            lock_screen
        fi
    done
) &

wait
