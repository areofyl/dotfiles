#!/bin/sh
# Link dotfiles into place. Run from the dotfiles dir.
# Usage: cd ~/dotfiles && ./install.sh

DIR="$(cd "$(dirname "$0")" && pwd)"

link() {
    mkdir -p "$(dirname "$2")"
    [ -e "$2" ] && rm -rf "$2"
    ln -s "$1" "$2"
    echo "  $2 -> $1"
}

echo "Linking dotfiles..."

for pkg in bat btop custom-lock dwl fetch git glance harper-ls irssi kitty lf nvim waybar wlim; do
    link "$DIR/$pkg" "$HOME/.config/$pkg"
done

link "$DIR/gtk/gtk-3.0" "$HOME/.config/gtk-3.0"
link "$DIR/gtk/gtk-4.0" "$HOME/.config/gtk-4.0"
link "$DIR/zsh/.zshrc"  "$HOME/.zshrc"

echo "Done."
