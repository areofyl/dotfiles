#!/bin/bash

#  ╔═══════════════════════════════════════════════════════════════════════════╗
#  ║                                                                           ║
#  ║   ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗      ║
#  ║   ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗     ║
#  ║   ███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║     ║
#  ║   ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║     ║
#  ║   ██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝     ║
#  ║   ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝      ║
#  ║                                                                           ║
#  ║              Fedora & Arch Dotfiles Install Script                        ║
#  ║                                                                           ║
#  ╚═══════════════════════════════════════════════════════════════════════════╝

set -e

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                              Colors                                       │
# └───────────────────────────────────────────────────────────────────────────┘
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                              Variables                                    │
# └───────────────────────────────────────────────────────────────────────────┘
DISTRO=""
AUR_HELPER=""

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                              Functions                                    │
# └───────────────────────────────────────────────────────────────────────────┘
print_header() {
    echo ""
    echo -e "${CYAN}╭───────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}$1${NC}"
    echo -e "${CYAN}╰───────────────────────────────────────────────────────────────╯${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}  ▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}  ✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}  ⚠${NC} $1"
}

print_error() {
    echo -e "${RED}  ✗${NC} $1"
}

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Distro Detection                                  │
# └───────────────────────────────────────────────────────────────────────────┘
detect_distro() {
    if [ -f /etc/fedora-release ]; then
        DISTRO="fedora"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
    else
        print_error "Unsupported distribution!"
        print_error "This script only supports Fedora and Arch Linux."
        exit 1
    fi
}

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         AUR Helper Setup (Arch)                           │
# └───────────────────────────────────────────────────────────────────────────┘
setup_aur_helper() {
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        print_success "Found AUR helper: yay"
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
        print_success "Found AUR helper: paru"
    else
        print_step "No AUR helper found. Installing yay..."

        # Install base-devel and git if not present
        sudo pacman -S --needed --noconfirm base-devel git

        # Clone and install yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay
        makepkg -si --noconfirm
        cd -
        rm -rf /tmp/yay

        AUR_HELPER="yay"
        print_success "Installed yay"
    fi
}

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Fedora Package Install                            │
# └───────────────────────────────────────────────────────────────────────────┘
install_fedora_packages() {
    print_header "Installing Core Packages (Fedora)"

    print_step "Installing Hyprland and core components..."
    sudo dnf install -y \
        hyprland \
        hyprlock \
        hypridle \
        xdg-desktop-portal-hyprland \
        waybar \
        kitty \
        rofi-wayland \
        neovim \
        emacs \
        SwayNotificationCenter \
        swww \
        wlogout \
        wallust \
        cava \
        btop \
        fastfetch \
        --quiet
    print_success "Core packages installed"

    print_header "Installing Utilities (Fedora)"

    print_step "Installing clipboard, screenshot, and media tools..."
    sudo dnf install -y \
        wl-clipboard \
        cliphist \
        grim \
        slurp \
        swappy \
        pamixer \
        brightnessctl \
        playerctl \
        polkit-kde \
        pavucontrol \
        blueman \
        network-manager-applet \
        thunar \
        thunar-archive-plugin \
        --quiet
    print_success "Utilities installed"

    print_header "Installing Theming Tools (Fedora)"

    print_step "Installing Qt and GTK theming tools..."
    sudo dnf install -y \
        qt5ct \
        qt6ct \
        kvantum \
        nwg-look \
        nwg-displays \
        --quiet
    print_success "Theming tools installed"

    print_header "Installing Fonts (Fedora)"

    print_step "Installing Nerd Fonts and icon fonts..."
    sudo dnf install -y \
        google-noto-sans-fonts \
        google-noto-sans-mono-fonts \
        jetbrains-mono-fonts-all \
        fontawesome-fonts-all \
        --quiet
    print_success "Fonts installed"

    print_header "Installing Zsh (Fedora)"

    print_step "Installing Zsh and plugins..."
    sudo dnf install -y \
        zsh \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        curl \
        git \
        --quiet
    print_success "Zsh installed"

    # Flatpak for Zen Browser
    print_step "Ensuring Flatpak is installed..."
    sudo dnf install -y flatpak --quiet
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Arch Package Install                              │
# └───────────────────────────────────────────────────────────────────────────┘
install_arch_packages() {
    print_header "Installing Core Packages (Arch)"

    print_step "Installing Hyprland and core components..."
    sudo pacman -S --needed --noconfirm \
        hyprland \
        hyprlock \
        hypridle \
        xdg-desktop-portal-hyprland \
        waybar \
        kitty \
        neovim \
        emacs \
        swaync \
        cava \
        btop \
        fastfetch
    print_success "Core packages installed"

    print_step "Installing AUR packages..."
    $AUR_HELPER -S --needed --noconfirm \
        rofi-lbonn-wayland-git \
        swww \
        wlogout \
        wallust
    print_success "AUR packages installed"

    print_header "Installing Utilities (Arch)"

    print_step "Installing clipboard, screenshot, and media tools..."
    sudo pacman -S --needed --noconfirm \
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
    print_success "Utilities installed"

    print_header "Installing Theming Tools (Arch)"

    print_step "Installing Qt and GTK theming tools..."
    sudo pacman -S --needed --noconfirm \
        qt5ct \
        qt6ct \
        kvantum \
        nwg-look

    $AUR_HELPER -S --needed --noconfirm nwg-displays
    print_success "Theming tools installed"

    print_header "Installing Fonts (Arch)"

    print_step "Installing Nerd Fonts and icon fonts..."
    sudo pacman -S --needed --noconfirm \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        ttf-jetbrains-mono-nerd \
        ttf-font-awesome
    print_success "Fonts installed"

    print_header "Installing Zsh (Arch)"

    print_step "Installing Zsh and plugins..."
    sudo pacman -S --needed --noconfirm \
        zsh \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        curl \
        git
    print_success "Zsh installed"

    # Flatpak for Zen Browser
    print_step "Ensuring Flatpak is installed..."
    sudo pacman -S --needed --noconfirm flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                          Pre-flight Checks                                │
# └───────────────────────────────────────────────────────────────────────────┘
clear
echo ""
echo -e "${MAGENTA}"
cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║     ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗     ║
    ║     ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝     ║
    ║     ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗       ║
    ║     ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝       ║
    ║     ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗     ║
    ║     ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝     ║
    ║                                                               ║
    ║              Hyprland + Waybar + Kitty + More                 ║
    ║                   Fedora & Arch Linux                         ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Detect distribution
detect_distro

if [ "$DISTRO" = "fedora" ]; then
    print_success "Detected: Fedora Linux"
elif [ "$DISTRO" = "arch" ]; then
    print_success "Detected: Arch Linux"
fi

# Get script directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
print_success "Dotfiles directory: $DOTFILES_DIR"

echo ""
echo -e "${BOLD}This script will install:${NC}"
echo ""
echo "  Window Manager    : Hyprland + Hyprlock + Hypridle"
echo "  Status Bar        : Waybar"
echo "  Terminal          : Kitty"
echo "  App Launcher      : Rofi"
echo "  Notifications     : SwayNotificationCenter"
echo "  File Manager      : Thunar"
echo "  Browser           : Ungoogled Chromium (Flatpak)"
echo "  Editors           : Neovim, Emacs"
echo "  Shell             : Zsh + Oh-My-Zsh"
echo "  Theming           : Qt5ct, Qt6ct, Kvantum, nwg-look"
echo "  System Control    : tuictl (TUI for wifi, bluetooth, audio, etc)"
echo "  Utilities         : Screenshot, clipboard, media controls"
echo "  And more..."
echo ""

read -p "$(echo -e ${YELLOW}"Proceed with installation? [y/N]: "${NC})" -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Installation cancelled"
    exit 0
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Installing Packages                               │
# └───────────────────────────────────────────────────────────────────────────┘

if [ "$DISTRO" = "fedora" ]; then
    install_fedora_packages
elif [ "$DISTRO" = "arch" ]; then
    setup_aur_helper
    install_arch_packages
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                       Installing Oh-My-Zsh                                │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Installing Oh-My-Zsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
    print_warning "Oh-My-Zsh already installed, skipping..."
else
    print_step "Downloading and installing Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_success "Oh-My-Zsh installed"
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                    Installing Ungoogled Chromium                          │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Installing Ungoogled Chromium"

print_step "Installing Ungoogled Chromium from Flathub..."
flatpak install -y flathub io.github.ungoogled_software.ungoogled_chromium
print_success "Ungoogled Chromium installed"

# Set up Chromium flags
if [ -f "$DOTFILES_DIR/.config/chromium-flags.conf" ]; then
    cp "$DOTFILES_DIR/.config/chromium-flags.conf" "$HOME/.config/chromium-flags.conf"
    print_success "Chromium flags configured"
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Setting Up Configs                                │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Setting Up Configuration Files"

# Create backup directory
backup_dir="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
print_step "Backup directory: $backup_dir"

# Ensure .config exists
mkdir -p "$HOME/.config"

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
    "gtk-4.0"
    "custom-lock"
    "swappy"
    "nwg-look"
    "nwg-displays"
    "nwg-panel"
    "xsettingsd"
    "quickshell"
    "org.gnome.Ptyxis"
)

print_step "Symlinking config files..."
for config in "${configs[@]}"; do
    if [ -e "$HOME/.config/$config" ] && [ ! -L "$HOME/.config/$config" ]; then
        mv "$HOME/.config/$config" "$backup_dir/"
        print_warning "Backed up existing $config"
    fi

    if [ -e "$DOTFILES_DIR/.config/$config" ]; then
        rm -rf "$HOME/.config/$config" 2>/dev/null || true
        ln -sf "$DOTFILES_DIR/.config/$config" "$HOME/.config/$config"
        print_success "Linked $config"
    fi
done

# Symlink home-level dotfiles
print_step "Setting up shell and home dotfiles..."
home_dotfiles=(".zshrc" ".zprofile" ".bashrc" ".bash_profile" ".gitconfig" ".gtkrc-2.0")
for dotfile in "${home_dotfiles[@]}"; do
    if [ -e "$HOME/$dotfile" ] && [ ! -L "$HOME/$dotfile" ]; then
        mv "$HOME/$dotfile" "$backup_dir/"
        print_warning "Backed up existing $dotfile"
    fi
    if [ -e "$DOTFILES_DIR/$dotfile" ]; then
        ln -sf "$DOTFILES_DIR/$dotfile" "$HOME/$dotfile"
        print_success "Linked $dotfile"
    fi
done

# Emacs config (lives in ~/.emacs.d, not ~/.config)
if [ -d "$DOTFILES_DIR/.emacs.d" ]; then
    print_step "Setting up Emacs config..."
    if [ -d "$HOME/.emacs.d" ] && [ ! -L "$HOME/.emacs.d" ]; then
        mv "$HOME/.emacs.d" "$backup_dir/"
        print_warning "Backed up existing .emacs.d"
    fi
    rm -rf "$HOME/.emacs.d" 2>/dev/null || true
    ln -sf "$DOTFILES_DIR/.emacs.d" "$HOME/.emacs.d"
    print_success "Linked .emacs.d"
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Setting Up Cursor Theme                          │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Setting Up Cursor Theme"

if [ -d "$DOTFILES_DIR/.local/share/icons/macOS-Tahoe" ]; then
    print_step "Installing macOS-Tahoe cursor theme..."
    mkdir -p "$HOME/.local/share/icons"
    cp -r "$DOTFILES_DIR/.local/share/icons/macOS-Tahoe" "$HOME/.local/share/icons/"
    print_success "macOS-Tahoe cursor theme installed"
fi

if [ -f "$DOTFILES_DIR/.icons/default/index.theme" ]; then
    print_step "Setting default X11 cursor..."
    mkdir -p "$HOME/.icons/default"
    cp "$DOTFILES_DIR/.icons/default/index.theme" "$HOME/.icons/default/index.theme"
    print_success "Default cursor set to macOS-Tahoe"
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Setting Up Wallpaper                              │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Setting Up Wallpaper"

print_step "Creating wallpapers directory..."
mkdir -p "$HOME/Pictures/wallpapers"

if [ -d "$DOTFILES_DIR/wallpapers" ]; then
    print_step "Copying wallpapers..."
    cp -r "$DOTFILES_DIR/wallpapers/"* "$HOME/Pictures/wallpapers/" 2>/dev/null || true
    print_success "Wallpapers copied to ~/Pictures/wallpapers"
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Installing tuictl                                 │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Installing tuictl (TUI System Control Panel)"

if command -v tuictl &> /dev/null; then
    print_success "tuictl already installed, updating..."
fi

# Install ncurses dev library (build dependency)
print_step "Installing ncurses development library..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y ncurses-devel gcc make pkg-config --quiet
elif [ "$DISTRO" = "arch" ]; then
    sudo pacman -S --needed --noconfirm ncurses gcc make pkg-config
fi

# Clone or update tuictl
if [ -d "$HOME/tuictl" ]; then
    print_step "Updating tuictl..."
    git -C "$HOME/tuictl" pull --quiet
else
    print_step "Cloning tuictl..."
    git clone https://github.com/areofyl/tuictl.git "$HOME/tuictl"
fi

# Build and install
print_step "Building tuictl..."
make -C "$HOME/tuictl" clean > /dev/null 2>&1
make -C "$HOME/tuictl" > /dev/null 2>&1

print_step "Installing tuictl to ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
install -m 755 "$HOME/tuictl/tuictl" "$HOME/.local/bin/tuictl"
print_success "tuictl installed"

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                         Setting Default Shell                             │
# └───────────────────────────────────────────────────────────────────────────┘
print_header "Setting Zsh as Default Shell"

if [ "$SHELL" != "$(which zsh)" ]; then
    print_step "Changing default shell to Zsh..."
    chsh -s $(which zsh)
    print_success "Default shell changed to Zsh"
else
    print_success "Zsh is already the default shell"
fi

# ┌───────────────────────────────────────────────────────────────────────────┐
# │                              Complete!                                    │
# └───────────────────────────────────────────────────────────────────────────┘
echo ""
echo -e "${GREEN}"
cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║                  ✓ INSTALLATION COMPLETE ✓                    ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BOLD}What was installed:${NC}"
echo ""
echo "  ✓ Hyprland window manager + Hyprlock + Hypridle"
echo "  ✓ Waybar status bar"
echo "  ✓ Kitty terminal"
echo "  ✓ Rofi app launcher"
echo "  ✓ Ungoogled Chromium"
echo "  ✓ Emacs + config"
echo "  ✓ Oh-My-Zsh"
echo "  ✓ tuictl system control panel"
echo "  ✓ All config files symlinked"
echo "  ✓ Wallpapers copied"
echo ""

echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "  1. Log out of your current session"
echo "  2. Select 'Hyprland' from your display manager"
echo "  3. Enjoy your new setup!"
echo ""

if [ -d "$backup_dir" ] && [ "$(ls -A $backup_dir 2>/dev/null)" ]; then
    echo -e "${YELLOW}Note:${NC} Your old configs were backed up to:"
    echo "      $backup_dir"
    echo ""
fi

echo -e "${CYAN}Keybinds to get started:${NC}"
echo ""
echo "  SUPER + Enter     : Open terminal"
echo "  SUPER + D         : Open app launcher"
echo "  SUPER + Q         : Close window"
echo "  SUPER + 1-9       : Switch workspace"
echo "  SUPER + Shift + S : Screenshot"
echo ""
echo -e "${MAGENTA}Happy ricing!${NC}"
echo ""
