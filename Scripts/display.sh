#!/usr/bin/env bash
# Display layouts (xrandr). Works with any external display (monitor,
# projector, TV) on any port, at the resolution it asks for.
#
#   display.sh [auto]                  dock if docked, else extend, else laptop
#   display.sh laptop                  internal display only
#   display.sh extend [OUT] [SIDE]     externals next to the laptop
#                                      SIDE = left|right|above|below (default left)
#   display.sh mirror [OUT]            same picture on laptop + external
#   display.sh external [OUT]          external only, laptop off (presenting)
#   display.sh mode OUT WxH            change one display's resolution
#   display.sh off OUT                 turn one display off
#   display.sh dock                    laptop + DP-1-2 horizontal + DP-1-3-1 vertical
#   display.sh hdmi                    = extend (kept for the `hdmi` alias)
#   display.sh list                    connected outputs: NAME STATE MODE PREFERRED
#
# OUT defaults to every connected external display. The DISPLAYS tab of
# Super+Space (Scripts/rofi_displays.sh) and the hotplug watcher
# (Scripts/display_hotplug.sh) both call this script.

LAPTOP=eDP-1
DOCK_H=DP-1-2      # horizontal external monitor of the dock
DOCK_V=DP-1-3-1    # vertical (rotated) external monitor of the dock

Q=$(xrandr --query)
connected() { grep -q "^$1 connected" <<<"$Q"; }
externals() { awk -v l="$LAPTOP" '$2 == "connected" && $1 != l { print $1 }' <<<"$Q"; }
preferred() {  # OUT -> its preferred mode (the one marked +), else the first
    awk -v o="$1" '
        $1 == o { on = 1; next }  /^[^ ]/ { on = 0 }
        on && /\+/ { print $1; exit }  on && !first { first = $1 }
        END { if (first) print first }' <<<"$Q" | head -n1
}
modes_of() { awk -v o="$1" '$1 == o { on = 1; next } /^[^ ]/ { on = 0 } on { print $1 }' <<<"$Q"; }
laptop_mode() { preferred "$LAPTOP"; }

off_others() {  # turn off every output not listed
    local o keep
    for o in $(awk '$2 ~ /connected/ { print $1 }' <<<"$Q"); do
        for keep in "$@"; do [ "$o" = "$keep" ] && continue 2; done
        xrandr --output "$o" --off 2>/dev/null
    done
}

layout_laptop() {
    off_others "$LAPTOP"
    xrandr --output "$LAPTOP" --primary --mode "$(laptop_mode)" --pos 0x0 --rotate normal
}

layout_extend() {  # [OUT] [SIDE]
    local outs side=left
    case "$1" in left|right|above|below) side=$1; shift ;; esac
    outs=${1:-$(externals)}
    [ -n "$2" ] && side=$2
    [ -z "$outs" ] && { layout_laptop; return; }
    off_others "$LAPTOP" $outs
    local args=(--output "$LAPTOP" --primary --mode "$(laptop_mode)" --rotate normal)
    local prev=$LAPTOP rel
    case $side in
        left) rel=--left-of ;; right) rel=--right-of ;;
        above) rel=--above ;; below) rel=--below ;;
    esac
    for o in $outs; do   # chain several externals on the same side
        args+=(--output "$o" --mode "$(preferred "$o")" --rotate normal --scale 1x1 $rel "$prev")
        prev=$o
    done
    xrandr "${args[@]}"
}

layout_mirror() {  # [OUT]
    local outs=${1:-$(externals)} lm o common
    [ -z "$outs" ] && { layout_laptop; return; }
    off_others "$LAPTOP" $outs
    lm=$(laptop_mode)
    local args=(--output "$LAPTOP" --primary --mode "$lm" --pos 0x0 --rotate normal)
    for o in $outs; do
        if modes_of "$o" | grep -qx "$lm"; then
            args+=(--output "$o" --mode "$lm" --scale 1x1 --same-as "$LAPTOP")
        else  # no shared resolution: run the external natively, scaled to fill
            args+=(--output "$o" --mode "$(preferred "$o")" --scale-from "$lm" --same-as "$LAPTOP")
        fi
    done
    xrandr "${args[@]}"
}

layout_external() {  # [OUT]
    local outs=${1:-$(externals)} first args=()
    [ -z "$outs" ] && { layout_laptop; return; }
    off_others $outs
    first=${outs%% *}
    local prev=""
    for o in $outs; do
        args+=(--output "$o" --mode "$(preferred "$o")" --rotate normal --scale 1x1)
        [ "$o" = "$first" ] && args+=(--primary --pos 0x0) || args+=(--right-of "$prev")
        prev=$o
    done
    xrandr "${args[@]}" --output "$LAPTOP" --off
}

layout_dock() {
    # Heights: vertical monitor is 1080x1920 -> total canvas height 1920
    # laptop  1366x768  centered vertically -> y = (1920-768)/2  = 576
    # DP-1-2  1920x1080 centered vertically -> y = (1920-1080)/2 = 420
    off_others "$LAPTOP" "$DOCK_H" "$DOCK_V"
    xrandr \
        --output "$LAPTOP" --primary --mode 1366x768 --pos 0x576 --rotate normal \
        --output "$DOCK_H" --mode 1920x1080 --pos 1366x420 --rotate normal \
        --output "$DOCK_V" --mode 1920x1080 --pos 3286x0 --rotate left
}

list() {
    local o state cur
    for o in $(awk '$2 == "connected" { print $1 }' <<<"$Q"); do
        cur=$(grep -m1 "^$o connected" <<<"$Q" | grep -oP '\d+x\d+(?=\+\d+\+\d+)')
        state=$([ -n "$cur" ] && echo on || echo off)
        echo "$o $state ${cur:--} $(preferred "$o")"
    done
}

cmd=${1:-auto}; shift
case "$cmd" in
    list)     list; exit ;;
    laptop)   layout_laptop ;;
    extend)   layout_extend "$@" ;;
    hdmi)     layout_extend "" left ;;
    mirror)   layout_mirror "$@" ;;
    external) layout_external "$@" ;;
    dock)     layout_dock ;;
    mode)     xrandr --output "$1" --mode "$2" --scale 1x1 ;;
    off)      [ "$1" = "$LAPTOP" ] && [ -z "$(externals)" ] || xrandr --output "$1" --off ;;
    auto)
        if connected "$DOCK_H" && connected "$DOCK_V"; then cmd=dock; layout_dock
        elif [ -n "$(externals)" ]; then cmd=extend; layout_extend
        else cmd=laptop; layout_laptop; fi ;;
    *) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

# Re-apply the theme: rebuilds the wallpaper for the new screen geometry and
# restarts polybar so every active output gets a bar
~/.config/Scripts/theme.sh apply >/dev/null 2>&1 &
