#!/bin/sh
# Force display off before suspend, then restore after
wlr-randr --output eDP-1 --off 2>/dev/null
wlr-randr --output DP-1 --off 2>/dev/null
systemctl suspend
sleep 1
wlr-randr --output eDP-1 --on --pos 0,0 2>/dev/null
