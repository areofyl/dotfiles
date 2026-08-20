#!/bin/sh
# Turn off all connected displays and wait for SMC events to settle before suspend
for output in $(wlr-randr 2>/dev/null | awk '/^[A-Za-z]/{print $1}'); do
    wlr-randr --output "$output" --off 2>/dev/null
done

# Wait for spurious SMC HID events from DP disconnect to drain
sleep 5

systemctl suspend

wlr-randr --output eDP-1 --on --pos 0,0 2>/dev/null
