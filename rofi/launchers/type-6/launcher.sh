#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10

dir="$HOME/.config/rofi/launchers/type-6"

## style-7 = dark (default), style-6 = light. Follows Scripts/theme.sh's mode.
mode=$(cat "$HOME/.cache/theme_mode" 2>/dev/null)
if [ "$mode" = "light" ]; then
    theme='style-6'
else
    theme='style-7'
fi

## Run
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi
