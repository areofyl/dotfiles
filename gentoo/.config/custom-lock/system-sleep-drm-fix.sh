#!/bin/sh
# Workaround for apple-drm suspend failure (error -22).
# Turns off Wayland outputs before suspend so the DRM driver
# doesn't choke, and re-enables them on resume.
#
# Install: sudo cp this /usr/lib/systemd/system-sleep/apple-drm-fix.sh
# systemd calls with: pre/post suspend/hibernate

USER_UID=1000
USER_NAME=aarav
RUNTIME_DIR="/run/user/$USER_UID"
WAYLAND_DISPLAY="wayland-0"

run_as_user() {
    sudo -u "$USER_NAME" \
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
        XDG_RUNTIME_DIR="$RUNTIME_DIR" \
        "$@"
}

case "$1" in
    pre)
        # Collect active outputs and turn them off
        outputs=$(run_as_user wlr-randr 2>/dev/null | awk '/^[^ ]/ {name=$1} /Enabled: yes/ {print name}')
        # Save for resume
        echo "$outputs" > /tmp/apple-drm-active-outputs
        for out in $outputs; do
            run_as_user wlr-randr --output "$out" --off
        done
        sleep 0.3
        ;;
    post)
        # Re-enable outputs saved before sleep
        if [ -f /tmp/apple-drm-active-outputs ]; then
            while read -r out; do
                [ -n "$out" ] && run_as_user wlr-randr --output "$out" --on
            done < /tmp/apple-drm-active-outputs
            rm -f /tmp/apple-drm-active-outputs
        fi
        ;;
esac
