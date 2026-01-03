#!/bin/bash

# Fedora Hyprland Dotfiles Install Script
# Run this on a fresh Fedora install

set -e

echo "=== Fedora Hyprland Dotfiles Installer ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Fedora
if ! grep -q "Fedora" /etc/os-release 2>/dev/null; then
    echo -e "${RED}This script is designed for Fedora Linux${NC}"
    exit 1
fi

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}Installing packages...${NC}"

# Core Hyprland packages
sudo dnf install -y \
    hyprland \
    hyprlock \
    xdg-desktop-portal-hyprland \
    waybar \
    kitty \
    rofi-wayland \
    neovim \
    SwayNotificationCenter \
    swww \
    wlogout \
    wallust \
    cava \
    btop \
    fastfetch

# Utilities
sudo dnf install -y \
    wl-clipboard \
    cliphist \
    grim \
    slurp \
    swappy \
    pamixer \
    brightnessctl \
    playerctl \
    polkit-gnome \
    pavucontrol \
    blueman \
    network-manager-applet \
    thunar \
    thunar-archive-plugin

# Theming
sudo dnf install -y \
    qt5ct \
    qt6ct \
    kvantum

# Shell
sudo dnf install -y \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting

# nwg tools
sudo dnf install -y \
    nwg-look \
    nwg-displays

# Fonts (optional but recommended)
sudo dnf install -y \
    google-noto-sans-fonts \
    google-noto-sans-mono-fonts \
    jetbrains-mono-fonts-all \
    fontawesome-fonts-all

echo ""
echo -e "${YELLOW}Creating config backups and symlinks...${NC}"

# Backup existing configs
backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

# List of configs to symlink
configs=(
    "hypr"
    "waybar"
    "kitty"
    "rofi"
    "nvim"
    "swaync"
    "eww"
    "cava"
    "btop"
    "fastfetch"
    "wlogout"
    "wallust"
    "qt5ct"
    "qt6ct"
    "Kvantum"
    "gtk-3.0"
)

for config in "${configs[@]}"; do
    if [ -e "$HOME/.config/$config" ]; then
        echo "Backing up existing $config..."
        mv "$HOME/.config/$config" "$backup_dir/"
    fi

    if [ -e "$DOTFILES_DIR/.config/$config" ]; then
        echo "Symlinking $config..."
        ln -sf "$DOTFILES_DIR/.config/$config" "$HOME/.config/$config"
    fi
done

# Symlink zsh configs
if [ -e "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$backup_dir/"
fi
if [ -e "$HOME/.zprofile" ]; then
    mv "$HOME/.zprofile" "$backup_dir/"
fi

ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"

echo ""
echo -e "${YELLOW}Setting zsh as default shell...${NC}"
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s $(which zsh)
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Log out and select Hyprland from your display manager"
echo "  2. If configs were backed up, they're in: $backup_dir"
echo ""
echo "Optional:"
echo "  - Install Zen Browser: flatpak install flathub app.zen_browser.zen"
echo "  - Install oh-my-zsh: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo ""
