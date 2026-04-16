#!/bin/sh
# Nimbus battery module — calculates time remaining from sysfs.
bat=/sys/class/power_supply/macsmc-battery

capacity=$(cat "$bat/capacity")
status=$(cat "$bat/status")
power=$(cat "$bat/power_now")
energy_now=$(cat "$bat/energy_now")
energy_full=$(cat "$bat/energy_full")

# Normalize power to positive
[ "$power" -lt 0 ] 2>/dev/null && power=$((-power))

# Determine charging state
charging=0
discharging=0
case "$status" in
    Charging)       charging=1 ;;
    Full|"Not charging") ;;
    *)              discharging=1 ;;
esac

# If status is ambiguous, fall back to AC presence
if [ "$charging" -eq 0 ] && [ "$discharging" -eq 0 ] && [ "$capacity" -lt 100 ]; then
    if [ -f /sys/class/power_supply/macsmc-ac/online ]; then
        ac=$(cat /sys/class/power_supply/macsmc-ac/online)
        if [ "$ac" = "1" ]; then
            charging=1
        else
            discharging=1
        fi
    fi
fi

# Build display text
if [ "$charging" -eq 1 ]; then
    text="[${capacity}%+]"
elif [ "$discharging" -eq 1 ]; then
    text="[${capacity}%-]"
else
    text="[${capacity}%]"
fi

# Calculate time remaining
tooltip="$capacity%"
if [ "$power" -gt 0 ] 2>/dev/null; then
    if [ "$discharging" -eq 1 ]; then
        mins=$(( (energy_now * 60) / power ))
        h=$((mins / 60))
        m=$((mins % 60))
        if [ "$h" -gt 0 ]; then
            tooltip="${capacity}% — ${h}h ${m}m left"
        else
            tooltip="${capacity}% — ${m}m left"
        fi
    elif [ "$charging" -eq 1 ]; then
        remaining=$((energy_full - energy_now))
        if [ "$remaining" -gt 0 ]; then
            mins=$(( (remaining * 60) / power ))
            h=$((mins / 60))
            m=$((mins % 60))
            if [ "$h" -gt 0 ]; then
                tooltip="${capacity}% — ${h}h ${m}m to full"
            else
                tooltip="${capacity}% — ${m}m to full"
            fi
        else
            tooltip="${capacity}% — full"
        fi
    fi
fi

# Class for styling
if [ "$charging" -eq 1 ]; then
    class="charging"
elif [ "$capacity" -le 10 ]; then
    class="critical"
elif [ "$capacity" -le 20 ]; then
    class="warning"
elif [ "$capacity" -le 50 ]; then
    class="medium"
else
    class="good"
fi

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$tooltip" "$class"
