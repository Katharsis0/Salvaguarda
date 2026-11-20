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

## Scan for Bluetooth devices while the launcher is open, so the DEVICES tab
## (Scripts/rofi_bt_battery.sh) can list what's nearby. BlueZ ties a scan to
## the client that started it, so it stops when we kill this one.
SCAN=""
if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
    bluetoothctl --timeout 120 scan on >/dev/null 2>&1 &
    SCAN=$!
    date +%s > "${XDG_RUNTIME_DIR:-/tmp}/bt_scan_started"
fi

## Run
## ←/→ switch tabs (APPS / DEVICES / FILES / HEALTH) instead of moving the
## text cursor; Ctrl+B / Ctrl+F still move the cursor.
rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi \
    -kb-move-char-back "Control+b" \
    -kb-move-char-forward "Control+f" \
    -kb-mode-previous "Left,Shift+Left,Control+ISO_Left_Tab" \
    -kb-mode-next "Right,Shift+Right,Control+Tab"

[ -n "$SCAN" ] && kill "$SCAN" 2>/dev/null
