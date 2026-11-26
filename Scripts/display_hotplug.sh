#!/usr/bin/env bash
# Hotplug watcher for displays, started by i3. When a display (monitor,
# projector, TV) is plugged in or unplugged, re-runs `display.sh auto`
# (dock layout if docked, else extend, else laptop only) and shows a
# notification; change the layout from Super+Shift+P (DISPLAYS tab).
# Without this, a newly plugged projector stays off and an unplugged one
# leaves windows on a screen that no longer exists.
#
# Polls the kernel's connector status files (cheap, no X calls) every 2 s.

NID=91921
state() { cat /sys/class/drm/card*-*/status 2>/dev/null | tr '\n' ' '; }
count() { grep -l '^connected' /sys/class/drm/card*-*/status 2>/dev/null | wc -l; }

prev=$(state); prev_n=$(count)
while sleep 2; do
    cur=$(state)
    [ "$cur" = "$prev" ] && continue
    sleep 1                     # let the display finish waking up (EDID)
    cur=$(state); n=$(count)
    ~/.config/Scripts/display.sh auto >/dev/null 2>&1
    if (( n > prev_n )); then
        dunstify -r $NID -i video-display "Display connected" \
            "Extended to the left. Super+Shift+P to mirror, present or rearrange." >/dev/null 2>&1
    else
        dunstify -r $NID -i video-display "Display disconnected" "Back to the laptop screen." >/dev/null 2>&1
    fi
    prev=$cur; prev_n=$n
done
