#!/bin/sh

# cursor theme
export XCURSOR_THEME=macOS-Tahoe
export XCURSOR_SIZE=24

# portal (file chooser, etc.)
export XDG_CURRENT_DESKTOP=sway
export GTK_USE_PORTAL=1

# bemenu theming
export BEMENU_OPTS="-i -c -W 0.4 -l 15 --binding vim --fn 'FantasqueSansM Nerd Font Mono 15' --tb '#1e1e1e' --tf '#ffffff' --fb '#1e1e1e' --ff '#ffffff' --nb '#1e1e1e' --nf '#ffffff' --hb '#333333' --hf '#ffffff' --sb '#333333' --sf '#ffffff'"

# clean up stale state
pkill -f 'tail.*dwl-status' 2>/dev/null
pkill -f 'cat /tmp/dwl-status' 2>/dev/null
rm -f /tmp/dwl-status

# start dwl under a D-Bus session (needed for xdg-desktop-portal)
# restart dwl on crash/signal unless the user explicitly quit (keybind touches quit flag)
exec dbus-run-session sh -c '
    quit_flag=/tmp/dwl-quit
    rm -f "$quit_flag"
    while true; do
        dwl -s ~/.config/dwl/startup.sh 2>>/tmp/dwl-error.log
        rc=$?
        if [ -f "$quit_flag" ]; then
            rm -f "$quit_flag"
            break
        fi
        echo "[$(date)] dwl exited (code $rc), restarting..." >> /tmp/dwl-error.log
        sleep 1
    done
'
