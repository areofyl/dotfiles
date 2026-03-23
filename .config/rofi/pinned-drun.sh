#!/bin/bash

# Pinned apps - these show at the top
# Format: "Name\0icon\x1ficon-name\x1finfo\x1fexec-cmd"

if [ -z "$1" ]; then
    # First run - show pinned apps then all drun apps
    # Pinned entries (with icons)
    echo -e "Ungoogled Chromium\0icon\x1fio.github.ungoogled_software.ungoogled_chromium\x1finfo\x1fflatpak run io.github.ungoogled_software.ungoogled_chromium"
    echo -e "Neovim\0icon\x1fnvim\x1finfo\x1fkitty nvim"
    echo -e "btop++\0icon\x1fbtop\x1finfo\x1fkitty btop"
    echo -e "\0nonselectable\x1ftrue"
    
    # Get all visible desktop apps, excluding pinned ones
    find /usr/share/applications /var/lib/flatpak/exports/share/applications \
        -maxdepth 1 -name '*.desktop' 2>/dev/null | while read -r f; do
        # Skip NoDisplay=true
        grep -q '^NoDisplay=true' "$f" 2>/dev/null && continue
        # Skip hidden ones from local overrides
        local_override="$HOME/.local/share/applications/$(basename "$f")"
        if [ -f "$local_override" ]; then
            grep -q '^NoDisplay=true' "$local_override" 2>/dev/null && continue
        fi
        
        name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
        icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
        exec_line=$(grep -m1 '^Exec=' "$f" | cut -d= -f2- | sed 's/ %[a-zA-Z]//g')
        type=$(grep -m1 '^Type=' "$f" | cut -d= -f2-)
        
        [ "$type" != "Application" ] && continue
        [ -z "$name" ] && continue
        
        # Skip pinned apps (already shown above)
        case "$name" in
            "Ungoogled Chromium"|"Neovim"|"btop++") continue ;;
        esac
        
        echo -e "${name}\0icon\x1f${icon}\x1finfo\x1f${exec_line}"
    done | sort
else
    # User selected something - get the exec command from info
    # $ROFI_INFO contains the exec command
    if [ -n "$ROFI_INFO" ]; then
        coproc ( eval "$ROFI_INFO" & )
        exit 0
    fi
fi
