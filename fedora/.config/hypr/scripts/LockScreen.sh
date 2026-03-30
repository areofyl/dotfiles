#!/usr/bin/env bash

# Ensure weather cache is up-to-date before locking
bash "$HOME/.config/hypr/UserScripts/WeatherWrap.sh" >/dev/null 2>&1 &

# Launch hyprlock
pidof hyprlock || hyprlock

