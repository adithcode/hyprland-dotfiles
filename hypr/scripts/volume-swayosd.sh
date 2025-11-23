#!/usr/bin/env bash
case "$1" in
  up)   pactl set-sink-volume @DEFAULT_SINK@ +5% ;;
  down) pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
  mute) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
  set)  pactl set-sink-volume @DEFAULT_SINK@ "$2"% ;;
esac

if command -v swayosd-client >/dev/null 2>&1; then
  swayosd-client show volume 2>/dev/null || swayosd-client show 2>/dev/null || true
else
  ~/.config/hypr/scripts/volume-osd.sh up  # fallback notify script (exists from before)
fi
