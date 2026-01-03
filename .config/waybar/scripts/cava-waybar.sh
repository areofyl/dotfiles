#!/bin/bash
# Cava visualizer for waybar - only shows when audio is playing

bar_chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

cava -p ~/.config/cava/config-waybar 2>/dev/null | while IFS=';' read -r -a levels; do
    output=""
    has_audio=false

    for val in "${levels[@]}"; do
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            # Check if there's actual audio (any value > 0)
            if [ "$val" -gt 0 ]; then
                has_audio=true
            fi
            idx=$((val > 7 ? 7 : val))
            output+="${bar_chars[$idx]}"
        fi
    done

    # Only show if there's actual audio activity
    if $has_audio; then
        echo "$output"
    else
        echo ""
    fi
done
