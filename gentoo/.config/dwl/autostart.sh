#!/bin/sh

# cursor theme
export XCURSOR_THEME=macOS-Tahoe
export XCURSOR_SIZE=24

# clean up stale state
pkill -f 'tail.*dwl-status' 2>/dev/null
pkill -f 'cat /tmp/dwl-status' 2>/dev/null
rm -f /tmp/dwl-status

# start dwl (status is piped to startup.sh's stdin, which writes it to /tmp/dwl-status)
dwl -s ~/.config/dwl/startup.sh 2>/tmp/dwl-error.log
