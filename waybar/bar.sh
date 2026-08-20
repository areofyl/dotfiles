#!/bin/sh
# Unified waybar helper — subcommands: tag, battery, produce-tags

case "$1" in
tag)
    # Usage: bar.sh tag [monitor] <tag-number 1-10>
    # Output classes: "selected", "occupied", "urgent", "empty"
    if [ $# -ge 3 ]; then
        mon=$2; tag=$3
        state_file="/tmp/dwl-tags-state-${mon}"
    else
        tag=$2
        state_file=/tmp/dwl-tags-state
    fi

    label=$tag
    [ "$tag" = "10" ] && label=0

    emit() {
        cls=$1
        if [ "$cls" = "empty" ] && [ "$tag" != "1" ]; then
            printf '{"text":"","class":"hidden"}\n'
            return
        fi
        if [ "$cls" = "selected" ]; then
            printf '{"text":"[%s]","class":"%s"}\n' "$label" "$cls"
        else
            printf '{"text":" %s ","class":"%s"}\n' "$label" "$cls"
        fi
    }

    [ -f "$state_file" ] || { emit empty; exit 0; }

    read -r occ sel urg < "$state_file"
    [ -z "$sel" ] && { emit empty; exit 0; }

    bit=$((1 << (tag - 1)))

    if [ $((urg & bit)) -ne 0 ]; then
        emit urgent
    elif [ $((sel & bit)) -ne 0 ]; then
        emit selected
    elif [ $((occ & bit)) -ne 0 ]; then
        emit occupied
    else
        emit empty
    fi
    ;;

battery)
    bat=/sys/class/power_supply/macsmc-battery

    status=$(cat "$bat/status")
    power=$(cat "$bat/power_now")
    energy_now=$(cat "$bat/energy_now")
    energy_full=$(cat "$bat/energy_full")

    if [ "$energy_full" -gt 0 ] 2>/dev/null; then
        capacity=$(( (energy_now * 100) / energy_full ))
        [ "$capacity" -gt 100 ] && capacity=100
    else
        capacity=$(cat "$bat/capacity")
    fi

    [ "$power" -lt 0 ] 2>/dev/null && power=$((-power))

    charging=0
    discharging=0
    case "$status" in
        Charging)       charging=1 ;;
        Full|"Not charging") ;;
        *)              discharging=1 ;;
    esac

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

    if [ "$charging" -eq 1 ]; then
        text="[${capacity}%+]"
    elif [ "$discharging" -eq 1 ]; then
        text="[${capacity}%-]"
    else
        text="[${capacity}%]"
    fi

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
    ;;

produce-tags)
    state_file=/tmp/dwl-tags-state
    sig=RTMIN+8
    signum=42

    : > "$state_file"

    waybar_signal_ready() {
        pids=$(pgrep -x waybar) || return 1
        [ -z "$pids" ] && return 1
        for pid in $pids; do
            sigcgt=$(awk '/^SigCgt:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
            [ -z "$sigcgt" ] && return 1
            bit=$(( (0x$sigcgt >> (signum - 1)) & 1 ))
            [ "$bit" -eq 1 ] || return 1
        done
        return 0
    }

    notify_waybar() {
        i=0
        while [ $i -lt 30 ]; do
            if waybar_signal_ready; then
                pkill -"$sig" waybar 2>/dev/null
                return 0
            fi
            sleep 0.1
            i=$((i + 1))
        done
    }

    tail -n 0 -F /tmp/dwl-status 2>/dev/null | while read -r line; do
        case "$line" in
            *" tags "*)
                set -- $line
                mon=$1
                occ=$3
                sel=$4
                urg=$6
                if [ "$sel" = "1023" ] || [ "$sel" = "511" ] || [ "$sel" = "63" ]; then
                    sel=1
                fi
                printf '%s %s %s\n' "$occ" "$sel" "$urg" > "${state_file}-${mon}"
                printf '%s %s %s\n' "$occ" "$sel" "$urg" > "$state_file"
                notify_waybar
                ;;
        esac
    done
    ;;

*)
    echo "Usage: bar.sh {tag|battery|produce-tags}" >&2
    exit 1
    ;;
esac
