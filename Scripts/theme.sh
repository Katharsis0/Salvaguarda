#!/bin/bash
# Usage: theme.sh [dark|light|toggle|apply]
# apply (default) re-applies whatever mode is currently saved, used at i3 startup.

DOTFILES="$HOME/GitHub/dotfiles"
STATE_FILE="$HOME/.cache/theme_mode"

current=$(cat "$STATE_FILE" 2>/dev/null)
[ -z "$current" ] && current="dark"

case "$1" in
    toggle)
        [ "$current" = "dark" ] && mode="light" || mode="dark"
        ;;
    dark|light)
        mode="$1"
        ;;
    *)
        mode="$current"
        ;;
esac

echo "$mode" > "$STATE_FILE"

cp "$DOTFILES/polybar/colors-$mode.ini" "$DOTFILES/polybar/colors-current.ini"

if [ "$mode" = "dark" ]; then
    "$DOTFILES/Scripts/wallpaper.sh" "$DOTFILES/desktop_bgs/death_bg.png"
    cp "$DOTFILES/alacritty/catppuccin-mocha.toml" "$DOTFILES/alacritty/theme-current.toml"
else
    "$DOTFILES/Scripts/wallpaper.sh" "$DOTFILES/desktop_bgs/light_bg.jpg"
    cp "$DOTFILES/alacritty/catppuccin-latte.toml" "$DOTFILES/alacritty/theme-current.toml"
fi

killall polybar 2>/dev/null
"$DOTFILES/polybar/launch.sh" &
