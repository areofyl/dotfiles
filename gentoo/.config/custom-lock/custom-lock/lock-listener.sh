#!/bin/sh
# Listen for logind Lock signal and trigger custom lock screen.
# Handles: power button short press, loginctl lock-session, lid close.

SESSION_PATH=""
while IFS= read -r line; do
    sid=$(echo "$line" | awk '{print $1}')
    stype=$(loginctl show-session "$sid" -p Type --value 2>/dev/null)
    if [ "$stype" = "wayland" ]; then
        SESSION_PATH=$(busctl call org.freedesktop.login1 \
            /org/freedesktop/login1 \
            org.freedesktop.login1.Manager \
            GetSession s "$sid" 2>/dev/null | awk '{print $2}' | tr -d '"')
        break
    fi
done <<EOF
$(loginctl list-sessions --no-legend 2>/dev/null)
EOF

if [ -z "$SESSION_PATH" ]; then
    exit 1
fi

gdbus monitor --system \
    --dest org.freedesktop.login1 \
    --object-path "$SESSION_PATH" 2>/dev/null | \
while read -r line; do
    if echo "$line" | grep -q "\.Lock ()"; then
        if ! pgrep -f "lockscreen.py" > /dev/null; then
            /home/aarav/.config/custom-lock/lock.sh &
        fi
    fi
done
