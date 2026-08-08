#!/bin/sh
# Turn off displays and wait for SMC events to settle before suspend
wlr-randr --output eDP-1 --off 2>/dev/null
wlr-randr --output DP-1 --off 2>/dev/null

# Wait for spurious SMC HID events from DP disconnect to drain
sleep 5

systemctl suspend

wlr-randr --output eDP-1 --on --pos 0,0 2>/dev/null
