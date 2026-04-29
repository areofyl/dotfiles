#!/bin/sh
# launched by dwl -s (dwl pipes status to our stdin)

# kill stale processes from a previous crashed session
pkill -x swaybg 2>/dev/null
pkill -x waybar 2>/dev/null
pkill -x swayidle 2>/dev/null
pkill -f 'xdg-desktop-portal' 2>/dev/null
pkill -f 'nimbus-tags-producer' 2>/dev/null
pkill -f 'glance watch' 2>/dev/null
pkill -f 'lock-listener' 2>/dev/null
pkill -f 'lockscreen.py' 2>/dev/null
pkill -f 'lock.sh' 2>/dev/null
rm -f /tmp/dwl-status /tmp/dwl-locked

# external display: force 2560x1440 if connected (preferred 4K@30 broken on apple-dcp)
if wlr-randr 2>/dev/null | grep -q 'DP-1'; then
    wlr-randr --output eDP-1 --pos 0,0 --output DP-1 --mode 3840x2160@30.000000 --pos 2560,0 &
else
    wlr-randr --output eDP-1 --pos 0,0 &
fi

sleep 1

# portal (file chooser, screenshare, etc.)
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY
/usr/libexec/xdg-desktop-portal-termfilechooser &
/usr/libexec/xdg-desktop-portal-gtk &
/usr/libexec/xdg-desktop-portal-wlr &
sleep 1 && /usr/libexec/xdg-desktop-portal -r &

# wallpaper
swaybg -i /home/aarav/Pictures/wallpapers/clouds.jpg -m fill &

# idle + lock + lock before suspend (lid close)
swayidle \
    timeout 240 'brightnessctl -s && brightnessctl set 50%' \
        resume 'brightnessctl -r' \
    timeout 300 'brightnessctl set 10%' \
        resume 'brightnessctl -r' \
    timeout 360 '/home/aarav/.config/custom-lock/lock.sh' \
    timeout 600 'systemctl suspend' \
    before-sleep '/home/aarav/.config/custom-lock/lock.sh' \
    after-resume 'wlr-randr --output eDP-1 --pos 0,0 --output DP-1 --mode 3840x2160@30.000000 --pos 2560,0' &

# listen for power button / loginctl lock-session (delay for session registration)
(sleep 3 && /home/aarav/.config/custom-lock/lock-listener.sh) &

# nimbus tags producer (writes /tmp/nimbus-tags-state, signals waybar)
~/.config/waybar/nimbus-tags-producer.sh &

# glance file watcher (transient waybar widget for new screenshots/downloads)
~/.local/bin/glance watch &

# status bar
waybar > /dev/null 2>&1 &

# forward dwl status (our stdin) to file for waybar's tail -f
# must stay in foreground to keep the stdin pipe alive
exec cat > /tmp/dwl-status
