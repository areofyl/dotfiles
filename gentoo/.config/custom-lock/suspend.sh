#!/bin/sh
# Suspend wrapper — turn off displays first so apple-drm doesn't choke.
# The DRM driver fails to suspend while outputs are active (error -22).

# Collect active outputs
outputs=$(wlr-randr 2>/dev/null | awk '/^[^ ]/ {name=$1} /Enabled: yes/ {print name}')

# Turn them all off
for out in $outputs; do
    wlr-randr --output "$out" --off
done

sleep 0.5

systemctl suspend
