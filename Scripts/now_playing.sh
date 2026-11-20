#!/bin/bash
# Polybar "now playing" (custom/script, tail = true): follows whatever player
# playerctl sees (Spotify, Firefox/Chrome, mpv...). Empty when nothing plays.
# Click = play/pause, scroll = next/previous (set in polybar/config.ini).
MAX=45
command -v playerctl >/dev/null || { echo ""; exec sleep infinity; }
playerctl --follow metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null |
while IFS='|' read -r status artist title; do
    [ -z "$title" ] && { echo ""; continue; }
    text="$title"; [ -n "$artist" ] && text="$artist — $title"
    (( ${#text} > MAX )) && text="${text:0:$((MAX - 1))}…"
    case "$status" in
        Playing) icon="󰏤" ;;     # shows the action a click performs
        *)       icon="󰐊" ;;
    esac
    echo "$icon  ${text//%/%%}"
done
