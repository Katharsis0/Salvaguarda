#!/bin/bash

current=$(setxkbmap -query | awk '/layout/{print $2}')

if [ "$current" = "latam" ]; then
    setxkbmap -layout us
else
    setxkbmap -layout latam
fi
