#!/bin/sh
# Reads dwl status from stdin and outputs JSON for waybar custom module

while read -r line; do
    case "$line" in
        *" tags "*)
            set -- $line
            occ=$3
            sel=$4
            urg=$6
            out=""
            for i in 1 2 3 4 5 6; do
                bit=$((1 << (i - 1)))
                if [ -n "$out" ]; then
                    out="$out <span color='#4a3f34'>|</span> "
                fi
                if [ $((sel & bit)) -ne 0 ]; then
                    out="$out<span color='#c08060'>$i</span>"
                elif [ $((urg & bit)) -ne 0 ]; then
                    out="$out<span color='#ff0000'>$i</span>"
                else
                    out="$out<span color='#7a6e62'>$i</span>"
                fi
            done
            for i in 7 8 9; do
                bit=$((1 << (i - 1)))
                if [ $((sel & bit)) -ne 0 ]; then
                    out="$out <span color='#4a3f34'>|</span> <span color='#c08060'>$i</span>"
                fi
            done
            printf '{"text": "%s"}\n' "$out"
            ;;
    esac
done
