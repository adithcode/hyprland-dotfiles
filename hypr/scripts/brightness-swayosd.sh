#!/usr/bin/env bash
case "$1" in
  up)   brightnessctl set +5% ;;
  down) brightnessctl set 5%- ;;
  set)  brightnessctl set "$2"% ;;
esac

if command -v swayosd-client >/dev/null 2>&1; then
  swayosd-client show brightness 2>/dev/null || swayosd-client show 2>/dev/null || true
else
  ~/.config/hypr/scripts/brightness-osd.sh up
fi
