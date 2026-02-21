#!/usr/bin/env bash
# Toggle an EWW popup window, closing others first

POPUP="$1"
POPUPS=("wifi-popup" "bluetooth-popup")

# Ensure daemon is running
eww ping 2>/dev/null || eww daemon &
sleep 0.1

# Check if the requested popup is already open
if eww active-windows 2>/dev/null | grep -q "^$POPUP:"; then
    eww close "$POPUP"
else
    # Close all other popups first
    for p in "${POPUPS[@]}"; do
        [[ "$p" != "$POPUP" ]] && eww close "$p" 2>/dev/null
    done
    eww open "$POPUP"
fi
