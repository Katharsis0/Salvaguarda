#!/bin/bash
# Rename the focused window's title (what i3 shows in tabbed/stacked layouts).
# Bound to $mod+n. Empty input restores the window's own title.
WID=$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $NF}')
CUR=$(xprop -id "$WID" _NET_WM_NAME 2>/dev/null | sed -n 's/^[^"]*"\(.*\)"$/\1/p')
NAME=$(rofi -dmenu -p "󰑕 Rename" -l 0 -filter "$CUR" \
       -theme-str 'window {width: 420px;} listview {enabled: false;}' </dev/null) || exit 0
if [ -z "$NAME" ]; then
    i3-msg -q 'title_format "%title"'
else
    NAME=${NAME//\\/\\\\}; NAME=${NAME//\"/\\\"}
    i3-msg -q "title_format \"$NAME\""
fi
