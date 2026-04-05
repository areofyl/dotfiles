#!/bin/sh
# launched by dwl -s (dwl pipes status to our stdin)

# external display: force 2560x1440 (preferred 4K@30 broken on apple-dcp)
wlr-randr --output DP-1 --mode 2560x1440@59.951000 --pos 2560,0 &

sleep 1

# wallpaper
swaybg -i /home/aarav/Pictures/wallpapers/clouds.jpg -m fill &

# idle + lock
swayidle timeout 300 '/home/aarav/.config/custom-lock/lock.sh' &

# listen for power button / loginctl lock-session
/home/aarav/.config/custom-lock/lock-listener.sh &

# status bar
waybar > /dev/null 2>&1 &

# forward dwl status (our stdin) to file for waybar's tail -f
# must stay in foreground to keep the stdin pipe alive
exec cat > /tmp/dwl-status
