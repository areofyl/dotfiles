# dotfiles

My Hyprland rice on Fedora / Arch Linux.

## What's included

| Category | Software |
|---|---|
| Window Manager | Hyprland + Hyprlock + Hypridle |
| Status Bar | Waybar |
| Terminal | Kitty |
| App Launcher | Rofi |
| Notifications | SwayNotificationCenter |
| Widgets | EWW |
| Editor | Neovim |
| Shell | Zsh + Oh-My-Zsh |
| File Manager | Thunar |
| Browser | Zen Browser (Flatpak) |
| Theming | Qt5ct, Qt6ct, Kvantum, nwg-look, Wallust |
| Extras | Cava, Btop, Fastfetch, Wlogout, Swappy |

## Configs

```
.config/
  hypr/          # Hyprland, Hypridle, keybinds, window rules
  waybar/        # Status bar modules and styling
  kitty/         # Terminal config
  rofi/          # App launcher, bluetooth, wifi menus
  nvim/          # Neovim (Lazy plugin manager)
  swaync/        # Notification center
  eww/           # EWW widgets and scripts
  cava/          # Audio visualizer
  btop/          # System monitor
  fastfetch/     # System info fetch
  wlogout/       # Logout screen
  wallust/       # Color theming from wallpaper
  gtk-3.0/       # GTK3 theme settings
  gtk-4.0/       # GTK4 theme settings
  qt5ct/         # Qt5 theme settings
  qt6ct/         # Qt6 theme settings
  Kvantum/       # Kvantum Qt theme
  nwg-look/      # GTK theme switcher
  nwg-displays/  # Display config
  nwg-panel/     # Panel config
  swappy/        # Screenshot editor
  warpd/         # Keyboard-driven pointer
  quickshell/    # Quickshell config
  xsettingsd/    # X settings daemon
```

## Installation

```bash
git clone https://github.com/areofyl/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script will:
1. Detect your distro (Fedora or Arch)
2. Install all required packages
3. Set up Oh-My-Zsh
4. Install Zen Browser via Flatpak
5. Back up your existing configs
6. Symlink everything into place
7. Set Zsh as your default shell

After installing, log out and select **Hyprland** from your display manager.
