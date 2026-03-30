#!/bin/sh
# Smart resize based on actual pixel position on screen.
# Usage: smart-resize.sh left|right|up|down [pixels]

direction="$1"
px="${2:-50}"

eval $(swaymsg -t get_outputs | python3 -c "
import json, sys
outputs = json.load(sys.stdin)
o = [x for x in outputs if x.get('focused') or x.get('current_workspace')]
if o:
    r = o[0]['rect']
    print(f\"sw={r['width']} sh={r['height']}\")
else:
    print('sw=2560 sh=1600')
")

eval $(swaymsg -t get_tree | python3 -c "
import json, sys
def find_focused(node):
    if node.get('focused'):
        return node
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        result = find_focused(child)
        if result:
            return result
    return None
tree = json.load(sys.stdin)
f = find_focused(tree)
if f:
    r = f['rect']
    cx = r['x'] + r['width'] // 2
    cy = r['y'] + r['height'] // 2
    print(f\"cx={cx} cy={cy}\")
else:
    print('cx=0 cy=0')
")

# If window center is in the right half, it's a "right" window and vice versa
right_half=$(( cx > sw / 2 ))
bottom_half=$(( cy > sh / 2 ))

case "$direction" in
    left)
        if [ "$right_half" -eq 1 ]; then
            swaymsg resize grow width "${px}px"
        else
            swaymsg resize shrink width "${px}px"
        fi
        ;;
    right)
        if [ "$right_half" -eq 1 ]; then
            swaymsg resize shrink width "${px}px"
        else
            swaymsg resize grow width "${px}px"
        fi
        ;;
    up)
        if [ "$bottom_half" -eq 1 ]; then
            swaymsg resize grow height "${px}px"
        else
            swaymsg resize shrink height "${px}px"
        fi
        ;;
    down)
        if [ "$bottom_half" -eq 1 ]; then
            swaymsg resize shrink height "${px}px"
        else
            swaymsg resize grow height "${px}px"
        fi
        ;;
esac
