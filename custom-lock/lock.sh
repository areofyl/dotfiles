#!/bin/sh
# Custom lock screen for DWL
# Usage: lock.sh          — lock the screen
#        lock.sh --listen  — listen for logind Lock/PrepareForSleep signals

case "$1" in
--listen)
    # Find the active session for current user
    SESSION_ID=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v uid="$(id -u)" '$2 == uid {print $1; exit}')
    [ -z "$SESSION_ID" ] && exit 1

    SESSION_PATH=$(busctl call org.freedesktop.login1 \
        /org/freedesktop/login1 \
        org.freedesktop.login1.Manager \
        GetSession s "$SESSION_ID" 2>/dev/null | awk '{print $2}' | tr -d '"')
    [ -z "$SESSION_PATH" ] && exit 1

    lock_screen() {
        if ! pgrep -f "lockscreen.py" > /dev/null; then
            /home/aarav/.config/custom-lock/lock.sh &
        fi
    }

    # Monitor session Lock signal (power button)
    gdbus monitor --system \
        --dest org.freedesktop.login1 \
        --object-path "$SESSION_PATH" 2>/dev/null | \
    while read -r line; do
        if echo "$line" | grep -q "\.Lock ()"; then
            lock_screen
        fi
    done &

    # Monitor PrepareForSleep (lid close / manual suspend)
    gdbus monitor --system \
        --dest org.freedesktop.login1 \
        --object-path /org/freedesktop/login1 2>/dev/null | \
    while read -r line; do
        if echo "$line" | grep -q "PrepareForSleep (true)"; then
            lock_screen
        fi
    done &

    wait
    ;;

*)
    LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dwl-locked"

    # Skip if already locked
    [ -f "$LOCK_FILE" ] && exit 0

    # Blank screen immediately
    SAVED_BRIGHTNESS=$(brightnessctl g 2>/dev/null)
    brightnessctl s 0 2>/dev/null

    touch "$LOCK_FILE"
    # Restart the lockscreen if it crashes
    (while [ -f "$LOCK_FILE" ]; do
        ~/.config/custom-lock/lockscreen
        [ -f "$LOCK_FILE" ] && sleep 0.5
    done) &
    sleep 0.4

    # Restore brightness once lockscreen overlay is covering the screen
    [ -n "$SAVED_BRIGHTNESS" ] && brightnessctl s "$SAVED_BRIGHTNESS" 2>/dev/null
    ;;
esac
