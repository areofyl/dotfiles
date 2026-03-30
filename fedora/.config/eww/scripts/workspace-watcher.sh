#!/bin/bash
# Watch for workspace changes and toggle dashboard on workspace 10

LAST_WS=""

while true; do
    CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

    if [ "$CURRENT_WS" != "$LAST_WS" ]; then
        if [ "$CURRENT_WS" = "10" ]; then
            eww open dashboard 2>/dev/null
        else
            eww close dashboard 2>/dev/null
        fi
        LAST_WS="$CURRENT_WS"
    fi

    sleep 0.2
done
