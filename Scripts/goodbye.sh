#!/bin/bash
# Show desktop_bgs/bye.jpg full screen for a moment, then log out / reboot /
# shut down. Used by every power menu (Super+O, power.sh, Super+Shift+E).
#   goodbye.sh poweroff|reboot|logout
ACTION=${1:-poweroff}
IMG="$HOME/GitHub/dotfiles/desktop_bgs/bye.jpg"
HOLD=1.8   # seconds on screen

case "$ACTION" in
    poweroff|reboot|logout) ;;
    *) echo "usage: $0 poweroff|reboot|logout" >&2; exit 1 ;;
esac

if [ -f "$IMG" ] && command -v feh >/dev/null; then
    # full screen, scaled to fit, black around it, no cursor
    feh --fullscreen --auto-zoom --image-bg black --hide-pointer \
        --no-menus --class goodbye "$IMG" &
    sleep "$HOLD"
fi

case "$ACTION" in
    poweroff) systemctl poweroff ;;
    reboot)   systemctl reboot ;;
    logout)   i3-msg -q exit ;;
esac
