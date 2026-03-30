#!/bin/bash
# Hide waybar on workspace 1, show on all others (2-10)
# Also redirect any new windows from workspace 1 to workspace 2

# Make sure eww daemon is running
eww daemon 2>/dev/null &

SOCKET_PATH="/run/user/$(id -u)/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Listen for window open events and move them if opened on workspace 1
nc -U "$SOCKET_PATH" | while read -r line; do
    if [[ "$line" == openwindow* ]]; then
        # Format: openwindow>>ADDR,WORKSPACE,CLASS,TITLE
        WINDOW_ADDR=$(echo "$line" | cut -d'>' -f3 | cut -d',' -f1)

        # Check which workspace this window is actually on
        WINDOW_WS=$(hyprctl clients -j | jq -r ".[] | select(.address == \"0x$WINDOW_ADDR\") | .workspace.id")

        if [ "$WINDOW_WS" = "1" ]; then
            hyprctl dispatch movetoworkspacesilent 2,address:0x$WINDOW_ADDR
            hyprctl dispatch workspace 2
        fi
    fi
done &

while true; do
    CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

    if [ "$CURRENT_WS" = "1" ]; then
        # Workspace 1: Kill waybar if running
        if pgrep -x waybar > /dev/null; then
            killall waybar 2>/dev/null
            eww open dashboard 2>/dev/null
        fi
    else
        # Any other workspace: Start waybar if not running
        if ! pgrep -x waybar > /dev/null; then
            waybar &
            eww close dashboard 2>/dev/null
        fi
    fi

    sleep 0.2
done
