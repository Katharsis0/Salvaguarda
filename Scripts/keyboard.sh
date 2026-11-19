#!/bin/bash
# Apply a keyboard layout plus the custom AltGr arrow keys (~/.config/xkb/symbols/arrows).
# Usage: keyboard.sh [layout]   (defaults to the current layout)
layout=${1:-$(setxkbmap -query | awk '/layout/{print $2}')}
setxkbmap -layout "$layout" -print \
  | sed -E 's/(xkb_symbols[^"]*"[^"]*)"/\1+level3(ralt_switch)+arrows(altgr)"/' \
  | xkbcomp -w 0 -I"$HOME/.config/xkb" - "$DISPLAY"
