#!/bin/bash
# Battery charge mode (needs setup_laptop.sh: TLP + a sudoers rule for these
# two TLP commands).
#   battery_charge.sh status   "limit" or "full"
#   battery_charge.sh full     charge both batteries to 100% once (trips)
#   battery_charge.sh limit    back to the 40-80% care limit
#   battery_charge.sh toggle   switch between the two (polybar battery click)
# The limit lives in the battery firmware: after a "full" charge it stays at
# 100% until you switch back (or TLP re-applies it at the next boot).

END=/sys/class/power_supply/BAT0/charge_control_end_threshold
notify() { notify-send -a Battery -i battery -r 9992 "$@"; }

status() { [ "$(cat "$END" 2>/dev/null)" -lt 100 ] 2>/dev/null && echo limit || echo full; }

case "${1:-status}" in
    status) status ;;
    full)
        if sudo -n /usr/bin/tlp fullcharge >/dev/null 2>&1; then
            notify "Battery: full charge" "Charging to 100% this time. Click the battery again to go back to the 80% limit."
        else
            notify -u critical "Battery" "Couldn't change the charge mode (run Scripts/setup_laptop.sh first)."; exit 1
        fi ;;
    limit)
        if sudo -n /usr/bin/tlp setcharge >/dev/null 2>&1; then
            notify "Battery: care limit" "Charging stops at 80% and restarts below 40%."
        else
            notify -u critical "Battery" "Couldn't change the charge mode (run Scripts/setup_laptop.sh first)."; exit 1
        fi ;;
    toggle) [ "$(status)" = limit ] && exec "$0" full || exec "$0" limit ;;
    *) sed -n '2,10p' "$0"; exit 1 ;;
esac
