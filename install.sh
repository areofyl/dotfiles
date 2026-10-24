#!/bin/sh
# Link dotfiles into place. Run from the dotfiles dir.
# Usage: cd ~/dotfiles && ./install.sh
set -eu

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
backup_dir=

link() {
    mkdir -p -- "$(dirname -- "$2")"
    if [ -L "$2" ] && [ "$(readlink -- "$2")" = "$1" ]; then
        return
    fi
    if [ -e "$2" ] || [ -L "$2" ]; then
        if [ -z "$backup_dir" ]; then
            state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
            mkdir -p -- "$state_dir"
            backup_dir=$(mktemp -d "$state_dir/install-XXXXXXXX")
            printf 'Preserving replaced configs in %s\n' "$backup_dir"
        fi
        mv -- "$2" "$backup_dir/$(basename -- "$2")"
    fi
    ln -s -- "$1" "$2"
    printf '  %s -> %s\n' "$2" "$1"
}

echo "Linking dotfiles..."

for pkg in bat btop custom-lock dwl fetch git glance harper-ls irssi kitty lf nvim vis waybar wlim; do
    link "$repo_dir/$pkg" "$HOME/.config/$pkg"
done

link "$repo_dir/gtk/gtk-3.0" "$HOME/.config/gtk-3.0"
link "$repo_dir/gtk/gtk-4.0" "$HOME/.config/gtk-4.0"
link "$repo_dir/zsh/.zshrc" "$HOME/.zshrc"
link "$repo_dir/mimeapps.list" "$HOME/.config/mimeapps.list"
link "$repo_dir/applications/vis.desktop" "$HOME/.local/share/applications/vis.desktop"
link "$repo_dir/scripts/dotfiles-sync" "$HOME/.local/bin/dotfiles-sync"
for unit in dotfiles-sync.service dotfiles-sync.timer; do
    link "$repo_dir/systemd/user/$unit" "$HOME/.config/systemd/user/$unit"
done
link "$repo_dir/systemd/user/dotfiles-sync.timer" \
    "$HOME/.config/systemd/user/timers.target.wants/dotfiles-sync.timer"

echo "Done."
