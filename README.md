# Nimbus

Dotfiles for my Gentoo Asahi Linux setup running on an M1 MacBook Air. Hostname is Nimbus - cloud to represent the MBA that's also powerful.

DWL on Wayland, compiled from source like everything else on here. Lock screen is a custom GTK4 app. Color palette is original.

## The Setup

This runs Gentoo on Apple Silicon through the Asahi Linux project with the Fairydust kernel. Everything is on the ~arm64 unstable branch, compiled with `-mcpu=apple-m1`. The whole system is Wayland-only, no X11 anywhere.

DWL is a dwm-style compositor for Wayland. It's tiny and does exactly what it needs to. I patch and recompile it when I want to change something, same way you would with dwm. Waybar handles the status bar, tuigreet handles login, and the lock screen is something I built from scratch in Python with GTK4 and gtk4-layer-shell.

## Hardware

- Apple MacBook Air M1 (2020)
- Asahi Linux with the Fairydust kernel for Display Port Alt Mode support
- 2560x1600 internal + 2560x1440 external via USB-C

## Stack

| | |
|---|---|
| Distro | Gentoo (~arm64, unstable) |
| Kernel | asahi-sources + Fairydust |
| Compositor | DWL |
| Bar | Waybar |
| Terminal | Kitty |
| Editor | Neovim |
| Shell | Zsh (standalone plugins, no framework) |
| Browser | Ungoogled Chromium |
| Lock Screen | Custom (GTK4 + Layer Shell) |
| Greeter | tuigreet |

## Color Palette

Original palette, not based on any existing theme. Dark and warm, used across the entire system: waybar, kitty, lock screen, DWL borders, tuigreet.

| | |
|---|---|
| Background | `#1a1510` |
| Foreground | `#d4c4b0` |
| Dim | `#7a6e62` |
| Sage | `#a0b89a` |
| Lavender | `#9a9ab8` |
| Orange | `#c08060` |

## Lock Screen

Custom lock screen written in Python using GTK4 and gtk4-layer-shell. Shows the time split into two large lines with the password field sliding in between when you start typing. Background is a blurred version of the current wallpaper. Picks a random quote from Sun Tzu or Technoblade each time.

PAM authentication uses a custom service with no artificial delay so unlocking feels instant.

## Power and Lid

Short press on the power button locks the screen. Long press shuts down. Closing the lid locks and suspends. Opening it wakes with the lock screen already showing. 5 minute idle timeout locks automatically. Wired through logind, a dbus listener script, and swayidle's before-sleep hook.

## DNS and Privacy

DNS queries go through Cloudflare over TLS via systemd-resolved. New WiFi connections are automatically configured to use encrypted DNS. System-wide adblock through /etc/hosts blocks ~170k ad and tracker domains.

## Dotfile Sync

A systemd user timer copies configs into this repo every hour, commits each changed file individually, and pushes.
