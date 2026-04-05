#!/bin/sh
# Listen for logind Lock and PrepareForSleep signals to trigger custom lock screen.
# Handles: power button short press, loginctl lock-session, lid close + suspend.

lock_screen() {
    if ! pgrep -f "lockscreen.py" > /dev/null; then
        /home/aarav/.config/custom-lock/lock.sh &
    fi
}

# Find the active session for current user
SESSION_ID=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v uid="$(id -u)" '$2 == uid {print $1; exit}')

if [ -z "$SESSION_ID" ]; then
    exit 1
fi

SESSION_PATH=$(busctl call org.freedesktop.login1 \
    /org/freedesktop/login1 \
    org.freedesktop.login1.Manager \
    GetSession s "$SESSION_ID" 2>/dev/null | awk '{print $2}' | tr -d '"')

if [ -z "$SESSION_PATH" ]; then
    exit 1
fi

# Monitor session Lock signal
gdbus monitor --system \
    --dest org.freedesktop.login1 \
    --object-path "$SESSION_PATH" 2>/dev/null | \
while read -r line; do
    if echo "$line" | grep -q "\.Lock ()"; then
        lock_screen
    fi
done &

# Monitor system PrepareForSleep signal (lid close → suspend)
gdbus monitor --system \
    --dest org.freedesktop.login1 \
    --object-path /org/freedesktop/login1 2>/dev/null | \
while read -r line; do
    if echo "$line" | grep -q "PrepareForSleep (true)"; then
        lock_screen
    fi
done &

wait
