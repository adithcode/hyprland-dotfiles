#!/usr/bin/env bash
# ~/scripts/wallpicker.sh
# GUI wallpaper picker using yad + swww (preferred) with pywal theming + Waybar switching
#
# Requirements:
#  - yad (for GUI)
#  - swww (preferred) OR hyprpaper
#  - pywal (wal)
#  - waybar configs: ~/.config/waybar/waybar-hdmi.jsonc and waybar-edp.jsonc (optional)
#  - (optional) ~/.config/pywal/apply_pywal.sh - if present, it will be used to apply theme
#
# Behavior:
#  - Pick an image with a file dialog
#  - Set wallpaper with swww (grow animation) or hyprpaper fallback
#  - Run 'wal -i' on the chosen image
#  - Call apply script if available, else:
#       - reload hyprland, restart waybar on appropriate monitor
#       - apply kitty colors via kitty remote (if kitty present)
#  - Send a notification when done

set -eu
WALLDIR="$HOME/Wallpapers"
SCRIPTDIR="$HOME/scripts"
PYWAL_APPLIER="$HOME/.config/pywal/apply_pywal.sh"

# create scripts dir if not exist (so user can store this)
mkdir -p "$SCRIPTDIR"

# sanity
[ -d "$WALLDIR" ] || { yad --info --title="Wallpicker" --text="Wallpapers folder not found: $WALLDIR"; exit 1; }

# Determine backend (swww preferred)
BACKEND="hyprpaper"
if command -v swww >/dev/null 2>&1; then
  BACKEND="swww"
  # ensure daemon running (swww-daemon)
  if ! pgrep -x swww-daemon >/dev/null 2>&1; then
    swww-daemon & sleep 0.35
  fi
fi

# File picker
SELECTED=$(yad --title="Wallpaper Picker" \
    --width=1000 --height=700 \
    --center \
    --file --filename="${WALLDIR}/" \
    --file-filter="Images | *.jpg *.jpeg *.png *.webp" \
    --button="gtk-ok:0" --button="gtk-cancel:1")

# If user cancelled or empty
if [ -z "$SELECTED" ]; then
  exit 0
fi

# In case yad returns "1|/path" etc. strip lines (keep last)
SELECTED=$(echo "$SELECTED" | tail -n1)

# Apply wallpaper with animation
if [ "$BACKEND" = "swww" ]; then
  # swww img <file> options:
  # use grow animation like in your original
  if ! swww img "$SELECTED" --transition-type grow --transition-duration 1.2 --transition-fps 60 >/dev/null 2>&1; then
    # fallback to hyprpaper if swww fails for some reason
    killall hyprpaper 2>/dev/null || true
    hyprpaper & sleep 0.12
    hyprctl hyprpaper preload "$SELECTED"
    hyprctl hyprpaper wallpaper ",$SELECTED"
  fi
else
  # hyprpaper fallback
  killall hyprpaper 2>/dev/null || true
  hyprpaper & sleep 0.12
  hyprctl hyprpaper preload "$SELECTED"
  hyprctl hyprpaper wallpaper ",$SELECTED"
fi

# Run pywal on the selected image
if command -v wal >/dev/null 2>&1; then
  wal -i "$SELECTED" || true
else
  notify-send "pywal not found" "Install pywal to generate colors from wallpaper"
fi

# Apply theme: prefer user-provided applier script if present
if [ -x "$PYWAL_APPLIER" ]; then
  "$PYWAL_APPLIER"
else
  # Basic apply steps if user hasn't provided a dedicated applier
  # 1) reload hyprland so it picks up colors-hyprland.conf (if sourced)
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload || true
  fi

  # 2) restart waybar and start the correct config based on HDMI presence
  # Kill existing waybar
  pkill waybar 2>/dev/null || true
  # Detect HDMI (exact name from hyprctl monitors)
  HDMI_NAME="HDMI-A-1"
  HDMI_CONNECTED=0
  if command -v hyprctl >/dev/null 2>&1; then
    # Count the monitor line that matches name & is not disabled
    if hyprctl monitors 2>/dev/null | grep -qE "^Monitor ${HDMI_NAME}|${HDMI_NAME}"; then
      # older/newer hyprctl formats vary; we'll check for the name and disabled status
      if hyprctl monitors 2>/dev/null | grep -A2 "$HDMI_NAME" | grep -q "disabled: false"; then
        HDMI_CONNECTED=1
      else
        # alternate simpler check: presence of the name in hyprctl output
        if hyprctl monitors 2>/dev/null | grep -q "$HDMI_NAME"; then
          HDMI_CONNECTED=1
        fi
      fi
    fi
  fi

  # Start appropriate waybar config if it exists, else start default waybar
  if [ "$HDMI_CONNECTED" -eq 1 ] && [ -f "$HOME/.config/waybar/waybar-hdmi.jsonc" ]; then
    nohup waybar -c "$HOME/.config/waybar/waybar-hdmi.jsonc" >/dev/null 2>&1 &
  elif [ -f "$HOME/.config/waybar/waybar-edp.jsonc" ]; then
    nohup waybar -c "$HOME/.config/waybar/waybar-edp.jsonc" >/dev/null 2>&1 &
  else
    nohup waybar >/dev/null 2>&1 &
  fi

  # 3) Apply kitty colors if kitty is installed and running
  if command -v kitty >/dev/null 2>&1; then
    if kitty @ ls >/dev/null 2>&1; then
      WALKITTY="$HOME/.cache/wal/colors-kitty.conf"
      if [ -f "$WALKITTY" ]; then
        kitty @ set-colors --all --config "$WALKITTY" >/dev/null 2>&1 || true
      fi
    fi
  fi
fi

# final notification
notify-send "Wallpaper set" "$(basename "$SELECTED") — theme applied"

exit 0
