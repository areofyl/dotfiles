#!/bin/bash
# Updates sway workspace names so waybar shows pacman-themed icons:
#   focused = pacman, occupied (not focused) = ghost, empty = dot

# Kill previous instances (exec_always can spawn duplicates on reload)
pkill -f "workspace-icons\.sh" -o 2>/dev/null

update_workspaces() {
    local occupied
    occupied=$(swaymsg -t get_workspaces --raw | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for w in data:
    rep = w.get('representation')
    if rep is not None and rep != '':
        print(w['num'])
")

    # Only rename workspaces that already exist — never create new ones
    local existing
    existing=$(swaymsg -t get_workspaces --raw | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for w in data:
    print(w['num'], w['name'])
")

    echo "$existing" | while read -r num current_name; do
        [ -z "$num" ] && continue

        local is_occupied=false
        for o in $occupied; do
            if [ "$num" = "$o" ]; then
                is_occupied=true
                break
            fi
        done

        if $is_occupied; then
            local target="$num:occupied"
        else
            local target="$num:empty"
        fi

        if [ "$current_name" != "$target" ]; then
            swaymsg "rename workspace \"$current_name\" to \"$target\"" 2>/dev/null
        fi
    done
}

# Initial update
sleep 0.5
update_workspaces

# Subscribe to relevant events and update on each
swaymsg -t subscribe '["window","workspace"]' --monitor | while read -r event; do
    sleep 0.1
    update_workspaces
done
