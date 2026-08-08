#!/bin/sh
# Nimbus tag-state producer.
# Tails /tmp/dwl-status, parses the "tags" lines, and writes the current
# (occ sel urg) triple to /tmp/nimbus-tags-state. The per-tag reader
# (nimbus-tag.sh) reads this file. Sends SIGRTMIN+8 to waybar on change
# so all 9 tag modules update immediately.

state_file=/tmp/nimbus-tags-state
sig=RTMIN+8
# Linux realtime signal number for RTMIN+8 (glibc RTMIN=34, so 34+8=42).
signum=42

: > "$state_file"

# Check whether *every* live waybar process has signal $signum in its
# caught-signal set (SigCgt in /proc/PID/status). If yes, it's safe to
# send the signal — otherwise we'd kill a half-started waybar, because
# the default action for an uncaught realtime signal is terminate.
waybar_signal_ready() {
    pids=$(pgrep -x waybar) || return 1
    [ -z "$pids" ] && return 1
    for pid in $pids; do
        sigcgt=$(awk '/^SigCgt:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
        [ -z "$sigcgt" ] && return 1
        # Bit (signum-1) of the SigCgt hex mask must be 1.
        bit=$(( (0x$sigcgt >> (signum - 1)) & 1 ))
        [ "$bit" -eq 1 ] || return 1
    done
    return 0
}

# Send the signal only if safe. Poll briefly so we don't drop an update,
# but also don't hang if waybar is genuinely gone.
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
            # "view all" pseudo-state → pretend only tag 1 is selected
            # 63=6 tags, 511=9 tags, 1023=10 tags
            if [ "$sel" = "1023" ] || [ "$sel" = "511" ] || [ "$sel" = "63" ]; then
                sel=1
            fi
            printf '%s %s %s\n' "$occ" "$sel" "$urg" > "${state_file}-${mon}"
            # backward compat: also write the focused monitor's state to the base file
            printf '%s %s %s\n' "$occ" "$sel" "$urg" > "$state_file"
            notify_waybar
            ;;
    esac
done
