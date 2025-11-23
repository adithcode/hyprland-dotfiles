#!/usr/bin/env bash

# Reload Hyprland colors
if [ -f ~/.cache/wal/colors-hyprland.conf ]; then
    hyprctl reload
fi

# Restart Waybar
pkill waybar
waybar & disown

# Reload Kitty colors
kitty @ set-colors --all --config ~/.cache/wal/colors-kitty.conf >/dev/null 2>&1

# Optional notification
notify-send "Pywal" "Theme applied"
