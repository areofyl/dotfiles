#!/usr/bin/env bash
# Session Save/Restore for Hyprland
# Saves window layouts (app, workspace, position, size, floating state)
# and restores them by relaunching apps and placing them accordingly.

SESSION_DIR="$HOME/.config/hypr/sessions"
mkdir -p "$SESSION_DIR"

NOTIFY=${NOTIFY:-true}

notify() {
    if [[ "$NOTIFY" == true ]]; then
        notify-send -t 3000 "Session Manager" "$1"
    fi
}

# Map window class to launch command
# Add custom mappings here for apps whose class doesn't match their binary
class_to_cmd() {
    local class="$1"
    case "$class" in
        # Flatpak apps
        io.github.ungoogled_software.ungoogled_chromium)
            echo "flatpak run io.github.ungoogled_software.ungoogled_chromium" ;;
        org.gnome.*)
            echo "flatpak run $class 2>/dev/null || ${class##*.}" ;;
        # Electron / special apps
        code|Code)          echo "code" ;;
        discord|Discord)    echo "discord" ;;
        spotify|Spotify)    echo "spotify" ;;
        steam|Steam)        echo "steam" ;;
        obsidian|Obsidian)  echo "obsidian" ;;
        # Terminals
        kitty)              echo "kitty" ;;
        foot)               echo "foot" ;;
        Alacritty)          echo "alacritty" ;;
        # File managers
        thunar|Thunar)      echo "thunar" ;;
        nautilus)           echo "nautilus" ;;
        org.gnome.Nautilus) echo "nautilus" ;;
        # Default: try lowercase class as command
        *)                  echo "${class,,}" ;;
    esac
}

# Save current session
do_save() {
    local name="${1:-default}"
    local file="$SESSION_DIR/${name}.json"

    hyprctl clients -j | jq '[.[] | select(.mapped == true and .hidden == false) | {
        class: .class,
        initialClass: .initialClass,
        title: .title,
        workspace: .workspace.id,
        workspaceName: .workspace.name,
        x: .at[0],
        y: .at[1],
        w: .size[0],
        h: .size[1],
        floating: .floating,
        fullscreen: .fullscreen,
        monitor: .monitor,
        pinned: .pinned
    }]' > "$file"

    local count
    count=$(jq length "$file")
    notify "Saved session '$name' ($count windows)"
    echo "Saved $count windows to $file"
}

# Restore a saved session
do_restore() {
    local name="${1:-default}"
    local file="$SESSION_DIR/${name}.json"

    if [[ ! -f "$file" ]]; then
        notify "Session '$name' not found"
        echo "Error: session '$name' not found at $file"
        return 1
    fi

    local count
    count=$(jq length "$file")
    notify "Restoring session '$name' ($count windows)..."

    # Track which classes are already running to avoid duplicates
    local running_classes
    running_classes=$(hyprctl clients -j | jq -r '.[].class' | sort)

    # Read each window entry and restore
    local i=0
    while IFS= read -r entry; do
        local class workspace floating fullscreen x y w h
        class=$(echo "$entry" | jq -r '.class')
        workspace=$(echo "$entry" | jq -r '.workspace')
        floating=$(echo "$entry" | jq -r '.floating')
        fullscreen=$(echo "$entry" | jq -r '.fullscreen')
        x=$(echo "$entry" | jq -r '.x')
        y=$(echo "$entry" | jq -r '.y')
        w=$(echo "$entry" | jq -r '.w')
        h=$(echo "$entry" | jq -r '.h')

        [[ -z "$class" || "$class" == "null" ]] && continue

        local cmd
        cmd=$(class_to_cmd "$class")

        echo "Restoring: $class -> workspace $workspace (${w}x${h} at ${x},${y})"

        # Launch the app on the target workspace using Hyprland dispatch rules
        # These rules apply only to the next window that matches
        hyprctl dispatch -- exec "[workspace $workspace silent]" "$cmd" &

        ((i++))
    done < <(jq -c '.[]' "$file")

    # Wait for windows to spawn
    echo "Waiting for windows to open..."
    sleep 3

    # Now apply positioning for floating windows
    while IFS= read -r entry; do
        local class workspace floating fullscreen x y w h
        class=$(echo "$entry" | jq -r '.class')
        workspace=$(echo "$entry" | jq -r '.workspace')
        floating=$(echo "$entry" | jq -r '.floating')
        fullscreen=$(echo "$entry" | jq -r '.fullscreen')
        x=$(echo "$entry" | jq -r '.x')
        y=$(echo "$entry" | jq -r '.y')
        w=$(echo "$entry" | jq -r '.w')
        h=$(echo "$entry" | jq -r '.h')

        [[ -z "$class" || "$class" == "null" ]] && continue

        # Apply floating state and position
        if [[ "$floating" == "true" ]]; then
            # Find the window address by class
            local addr
            addr=$(hyprctl clients -j | jq -r --arg c "$class" \
                '[.[] | select(.class == $c)] | last | .address // empty')
            if [[ -n "$addr" ]]; then
                hyprctl dispatch focuswindow "address:$addr"
                hyprctl dispatch setfloating
                hyprctl dispatch movewindowpixel "exact $x $y,address:$addr"
                hyprctl dispatch resizewindowpixel "exact $w $h,address:$addr"
            fi
        fi

        # Apply fullscreen
        if [[ "$fullscreen" == "1" ]]; then
            local addr
            addr=$(hyprctl clients -j | jq -r --arg c "$class" \
                '[.[] | select(.class == $c)] | last | .address // empty')
            if [[ -n "$addr" ]]; then
                hyprctl dispatch focuswindow "address:$addr"
                hyprctl dispatch fullscreen 1
            fi
        elif [[ "$fullscreen" == "2" ]]; then
            local addr
            addr=$(hyprctl clients -j | jq -r --arg c "$class" \
                '[.[] | select(.class == $c)] | last | .address // empty')
            if [[ -n "$addr" ]]; then
                hyprctl dispatch focuswindow "address:$addr"
                hyprctl dispatch fullscreen 2
            fi
        fi
    done < <(jq -c '.[]' "$file")

    notify "Session '$name' restored ($i windows)"
    echo "Restored $i windows"
}

# List saved sessions
do_list() {
    echo "Saved sessions:"
    for f in "$SESSION_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local name count
        name=$(basename "$f" .json)
        count=$(jq length "$f")
        local modified
        modified=$(date -r "$f" '+%Y-%m-%d %H:%M')
        echo "  $name ($count windows) - $modified"
    done
}

# Delete a session
do_delete() {
    local name="${1:-default}"
    local file="$SESSION_DIR/${name}.json"
    if [[ -f "$file" ]]; then
        rm "$file"
        notify "Deleted session '$name'"
        echo "Deleted session '$name'"
    else
        echo "Session '$name' not found"
        return 1
    fi
}

# Show session contents
do_show() {
    local name="${1:-default}"
    local file="$SESSION_DIR/${name}.json"
    if [[ ! -f "$file" ]]; then
        echo "Session '$name' not found"
        return 1
    fi
    echo "Session '$name':"
    jq -r '.[] | "  [\(.workspace)] \(.class) \(.w)x\(.h) \(if .floating then "(floating)" else "" end) \(if .fullscreen > 0 then "(fullscreen)" else "" end)"' "$file"
}

# Rofi picker for restore
do_rofi_restore() {
    local sessions=()
    for f in "$SESSION_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local name count
        name=$(basename "$f" .json)
        count=$(jq length "$f")
        sessions+=("$name ($count windows)")
    done

    if [[ ${#sessions[@]} -eq 0 ]]; then
        notify "No saved sessions"
        return 1
    fi

    local choice
    choice=$(printf '%s\n' "${sessions[@]}" | rofi -dmenu -p "Restore Session" -i)
    [[ -z "$choice" ]] && return

    # Extract session name (strip the count)
    local name="${choice%% (*}"
    do_restore "$name"
}

# Rofi picker for save
do_rofi_save() {
    local existing=""
    for f in "$SESSION_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        existing+="$(basename "$f" .json)\n"
    done

    local name
    name=$(echo -e "${existing}New session..." | rofi -dmenu -p "Save Session As" -i)
    [[ -z "$name" ]] && return

    if [[ "$name" == "New session..." ]]; then
        name=$(rofi -dmenu -p "Session name" -lines 0)
        [[ -z "$name" ]] && return
    fi

    do_save "$name"
}

# Main
case "${1:-}" in
    save)    do_save "$2" ;;
    restore) do_restore "$2" ;;
    list)    do_list ;;
    show)    do_show "$2" ;;
    delete)  do_delete "$2" ;;
    rofi-save)    do_rofi_save ;;
    rofi-restore) do_rofi_restore ;;
    *)
        echo "Usage: $(basename "$0") {save|restore|list|show|delete|rofi-save|rofi-restore} [name]"
        echo ""
        echo "Commands:"
        echo "  save [name]     Save current window layout (default: 'default')"
        echo "  restore [name]  Restore a saved layout"
        echo "  list            List all saved sessions"
        echo "  show [name]     Show windows in a session"
        echo "  delete [name]   Delete a saved session"
        echo "  rofi-save       Save with rofi picker"
        echo "  rofi-restore    Restore with rofi picker"
        ;;
esac
