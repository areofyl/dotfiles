#!/bin/sh
# Per-tag state reader for waybar.
# Usage: nimbus-tag.sh <tag-number 1-9>
# Reads the latest dwl tags line from /tmp/nimbus-tags-state (maintained by
# nimbus-tags-producer.sh) and outputs JSON for a single tag's waybar module.
#
# Output classes: "selected", "occupied", "urgent", "empty"

tag=$1
state_file=/tmp/nimbus-tags-state

# Display label: 10 shown as "0" to match the keybind (Super+0)
label=$tag
[ "$tag" = "10" ] && label=0

emit() {
    # $1 = class
    # Empty tags are hidden so the bar only shows tags in use.
    # Exception: tag 1 is always visible (anchor / default workspace).
    cls=$1
    if [ "$cls" = "empty" ] && [ "$tag" != "1" ]; then
        printf '{"text":"","class":"hidden"}\n'
        return
    fi
    printf '{"text":"%s","class":"%s"}\n' "$label" "$cls"
}

[ -f "$state_file" ] || { emit empty; exit 0; }

# shellcheck disable=SC2034
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
