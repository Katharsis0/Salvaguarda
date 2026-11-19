#!/bin/bash

current=$(setxkbmap -query | awk '/layout/{print $2}')

if [ "$current" = "latam" ]; then
    ~/.config/Scripts/keyboard.sh us
else
    ~/.config/Scripts/keyboard.sh latam
fi
