#!/bin/sh
# Nimbus tag-state producer.
# Tails /tmp/dwl-status, parses the "tags" lines, and writes the current
# (occ sel urg) triple to /tmp/nimbus-tags-state. The per-tag reader
# (nimbus-tag.sh) reads this file. Sends SIGRTMIN+8 to waybar on change
# so all 9 tag modules update immediately.

state_file=/tmp/nimbus-tags-state
sig=RTMIN+8

: > "$state_file"

# Wait for waybar to be up and have its signal handlers installed before
# sending RTMIN+8. Otherwise the default action for an unhandled RT signal
# is to terminate waybar, which races on startup.
waybar_ready() {
    for pid in $(pgrep -x waybar); do
        state=$(awk '/^State:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
        [ -n "$state" ] && [ "$state" != "Z" ] && return 0
    done
    return 1
}
while ! waybar_ready; do sleep 0.1; done
sleep 1

tail -n 0 -F /tmp/dwl-status 2>/dev/null | while read -r line; do
    case "$line" in
        *" tags "*)
            set -- $line
            occ=$3
            sel=$4
            urg=$6
            # "view all" pseudo-state → pretend only tag 1 is selected
            # 63=6 tags, 511=9 tags, 1023=10 tags
            if [ "$sel" = "1023" ] || [ "$sel" = "511" ] || [ "$sel" = "63" ]; then
                sel=1
            fi
            printf '%s %s %s\n' "$occ" "$sel" "$urg" > "$state_file"
            pkill -"$sig" waybar 2>/dev/null
            ;;
    esac
done
