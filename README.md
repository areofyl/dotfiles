# dotfiles

Config files for my setups, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Setups

### gentoo — Sway on Asahi Linux (Apple Silicon)

| Category | Software |
|---|---|
| Window Manager | Sway |
| Status Bar | Waybar |
| Terminal | Kitty |
| App Launcher | wmenu |
| Notifications | Mako |
| Editor | Neovim |
| Shell | Zsh (standalone plugins) |
| File Manager | Thunar |
| Browser | Firefox |
| Lock | swaylock + swayidle |

### fedora — Hyprland on Fedora

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

## Usage

```bash
git clone https://github.com/areofyl/dotfiles ~/dotfiles
cd ~/dotfiles
stow gentoo    # or: stow fedora
```

The fedora setup also has an install script (`fedora/install.sh`) that handles package installation.
