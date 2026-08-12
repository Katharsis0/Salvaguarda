#!/usr/bin/env bash
# Display layouts. Usage: display.sh [auto|dock|hdmi|laptop]
# dock   : laptop (left) + DP-1-2 horizontal (middle) + DP-1-3-1 vertical (right)
# hdmi   : HDMI-2 (left) + laptop (right)
# laptop : internal display only

LAPTOP=eDP-1
DOCK_H=DP-1-2      # horizontal external monitor
DOCK_V=DP-1-3-1    # vertical (rotated) external monitor
HDMI=HDMI-2

connected() { xrandr --query | grep -q "^$1 connected"; }

off_others() {
  for o in $(xrandr --query | grep -E "^\S+ (dis)?connected" | cut -d" " -f1); do
    for keep in "$@"; do
      [ "$o" = "$keep" ] && continue 2
    done
    xrandr --output "$o" --off 2>/dev/null
  done
}

layout_dock() {
  # Heights: vertical monitor is 1080x1920 -> total canvas height 1920
  # laptop  1366x768  centered vertically -> y = (1920-768)/2  = 576
  # DP-1-2  1920x1080 centered vertically -> y = (1920-1080)/2 = 420
  off_others "$LAPTOP" "$DOCK_H" "$DOCK_V"
  xrandr \
    --output "$LAPTOP" --primary --mode 1366x768 --pos 0x576 --rotate normal \
    --output "$DOCK_H" --mode 1920x1080 --pos 1366x420 --rotate normal \
    --output "$DOCK_V" --mode 1920x1080 --pos 3286x0 --rotate left
}

layout_hdmi() {
  off_others "$LAPTOP" "$HDMI"
  xrandr \
    --output "$HDMI" --mode 1920x1080 --pos 0x0 --rotate normal \
    --output "$LAPTOP" --primary --mode 1366x768 --pos 1920x312 --rotate normal
}

layout_laptop() {
  off_others "$LAPTOP"
  xrandr --output "$LAPTOP" --primary --mode 1366x768 --pos 0x0 --rotate normal
}

case "${1:-auto}" in
  dock)   layout_dock ;;
  hdmi)   layout_hdmi ;;
  laptop) layout_laptop ;;
  auto)
    if connected "$DOCK_H" && connected "$DOCK_V"; then
      layout_dock
    elif connected "$HDMI"; then
      layout_hdmi
    else
      layout_laptop
    fi
    ;;
  *) echo "usage: $0 [auto|dock|hdmi|laptop]" >&2; exit 1 ;;
esac

# Re-apply the theme: rebuilds the wallpaper for the new screen geometry and
# restarts polybar so every active output gets a bar
~/.config/Scripts/theme.sh apply >/dev/null 2>&1 &
