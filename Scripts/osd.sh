#!/bin/bash
# On-screen bar for the volume / brightness / mic keys (a dunst notification
# with a progress bar that replaces itself instead of stacking).
#   osd.sh volume up|down [step]   (default step 5)
#   osd.sh volume mute
#   osd.sh mic mute
#   osd.sh brightness up|down [step]   (default step 10)

show() {  # show TAG ICON TEXT [PERCENT]
    local args=(-a OSD -u low -t 1500 -h "string:x-dunst-stack-tag:$1" -i "$2")
    [ -n "${4:-}" ] && args+=(-h "int:value:$4")
    dunstify "${args[@]}" "$3" >/dev/null 2>&1
}
vol()   { pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -n1; }
muted() { pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes; }

case "$1" in
    volume)
        case "$2" in
            up)   pactl set-sink-mute @DEFAULT_SINK@ 0
                  # cap at 100%: louder only distorts the laptop speakers
                  v=$(vol); step=${3:-5}; (( v + step > 100 )) && step=$(( 100 - v ))
                  (( step > 0 )) && pactl set-sink-volume @DEFAULT_SINK@ "+${step}%" ;;
            down) pactl set-sink-volume @DEFAULT_SINK@ "-${3:-5}%" ;;
            mute) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
        esac
        v=$(vol)
        if muted; then show volume audio-volume-muted "Muted" 0
        else
            if   (( v == 0 )); then icon=audio-volume-muted
            elif (( v < 34 )); then icon=audio-volume-low
            elif (( v < 67 )); then icon=audio-volume-medium
            else                    icon=audio-volume-high; fi
            show volume "$icon" "Volume  $v%" "$v"
        fi ;;
    mic)
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes; then
            show mic microphone-sensitivity-muted "Microphone off"
        else
            show mic audio-input-microphone "Microphone on"
        fi ;;
    brightness)
        case "$2" in
            up)   brightnessctl -q set "+${3:-10}%" ;;
            down) # never all the way to black
                  cur=$(brightnessctl -m | cut -d, -f4 | tr -d %)
                  (( cur - ${3:-10} >= 5 )) && brightnessctl -q set "${3:-10}%-" || brightnessctl -q set 5% ;;
        esac
        b=$(brightnessctl -m | cut -d, -f4 | tr -d %)
        show brightness display-brightness "Brightness  $b%" "$b" ;;
    *) sed -n '2,7p' "$0"; exit 1 ;;
esac
