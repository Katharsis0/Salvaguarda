#!/bin/bash
# rofi script-mode tab "DISPLAYS" of the Super+Space launcher (rofi type-6).
# Also opened directly with Super+Shift+P or the laptop's display key.
#   * layouts: Laptop only / Extend (left, right, above) / Mirror /
#     External only (presenting on a projector); the active one is marked
#   * each external display -> resolution list, turn off
#   * Advanced (arandr) for anything else, Refresh
# All changes go through Scripts/display.sh. The menu stays open after every
# action (Esc closes it).

D=~/.config/Scripts/display.sh
LAPTOP=eDP-1

opt()  { printf '\0%s\x1f%s\n' "$1" "$2"; }
item() { printf '%s\0info\x1f%s\n' "$1" "$2"; }
dim()  { printf '<span alpha="55%%">%s</span>' "$1"; }
pad()  { local s=${1:0:$2}; printf '%s%*s' "$s" $(( $2 - ${#s} )) ''; }
mark() { [ "$1" = "$2" ] && printf '  <span alpha="55%%">● active</span>'; }

opt no-custom true
opt markup-rows true
[ -n "${ROFI_INFO:-}" ] && opt keep-selection true

# ------------------------------------------------------------------ actions
case "${ROFI_INFO:-}" in
    layout:*)  IFS=: read -r _ l a b <<<"$ROFI_INFO"; $D "$l" $a $b >/dev/null 2>&1; sleep 0.5 ;;
    mode:*)    IFS=: read -r _ o m <<<"$ROFI_INFO";  $D mode "$o" "$m" >/dev/null 2>&1; sleep 0.5 ;;
    off:*)     $D off "${ROFI_INFO#off:}" >/dev/null 2>&1; sleep 0.5 ;;
    arandr)    setsid -f arandr >/dev/null 2>&1; exit 0 ;;
    out:*)     # submenu for one display
        o=${ROFI_INFO#out:}
        read -r _ state cur pref < <($D list | grep "^$o ")
        opt message "$o — $( [ "$state" = on ] && echo "$cur" || echo off )"
        item "󰁍   Back" "refresh"
        while read -r m; do
            tag=""; [ "$m" = "$cur" ] && tag="  $(dim '● current')"
            [ "$m" = "$pref" ] && tag+="  $(dim recommended)"
            item "󰍹   $m$tag" "mode:$o:$m"
        done < <(xrandr --query | awk -v o="$o" '$1 == o { on = 1; next } /^[^ ]/ { on = 0 } on { print $1 }' | awk '!seen[$0]++')
        [ "$state" = on ] && item "󰶐   Turn $o off" "off:$o"
        exit 0 ;;
esac

# ------------------------------------------------------------------ state
declare -A STATE CUR POS
ext=()
while read -r o state cur pref; do
    STATE[$o]=$state; CUR[$o]=$cur
    [ "$o" != "$LAPTOP" ] && ext+=("$o")
done < <($D list)
while read -r o geo; do POS[$o]=${geo#*+}; done < <(
    xrandr --query | awk '$2 == "connected" { for (i = 3; i <= NF; i++) if ($i ~ /^[0-9]+x[0-9]+\+/) print $1, $i }')

# which layout is active right now
ext_on=0
for o in "${ext[@]}"; do [ "${STATE[$o]}" = on ] && ((ext_on++)); done
if (( ext_on == 0 )); then
    active=laptop
elif [ "${STATE[$LAPTOP]}" = off ]; then
    active=external
else
    active=extend
    for o in "${ext[@]}"; do
        [ "${STATE[$o]}" = on ] && [ "${POS[$o]}" = "${POS[$LAPTOP]}" ] && active=mirror
    done
    if [ $active = extend ]; then   # which side is the first external on?
        IFS=+ read -r lx ly <<<"${POS[$LAPTOP]}"
        for o in "${ext[@]}"; do
            [ "${STATE[$o]}" = on ] || continue
            IFS=+ read -r ex ey <<<"${POS[$o]}"
            if   (( ex < lx )); then active=extend-left
            elif (( ex > lx )); then active=extend-right
            elif (( ey < ly )); then active=extend-above
            else                     active=extend-below; fi
            break
        done
    fi
fi

summary=""
for o in "$LAPTOP" "${ext[@]}"; do
    [ -n "${STATE[$o]}" ] || continue
    summary+="$o $( [ "${STATE[$o]}" = on ] && echo "${CUR[$o]}" || echo off)   "
done
opt message "$summary"

# ------------------------------------------------------------------ list
if (( ${#ext[@]} == 0 )); then
    item "󰍹   No external display connected  $(dim 'plug one in, then Refresh')" "refresh"
else
    item "󰌢   $(pad 'Laptop only' 30)$(mark "$active" laptop)"                       "layout:laptop"
    item "󰍺   $(pad 'Extend — left of laptop' 30)$(mark "$active" extend-left)"     "layout:extend:left"
    item "󰍺   $(pad 'Extend — right of laptop' 30)$(mark "$active" extend-right)"   "layout:extend:right"
    item "󰍺   $(pad 'Extend — above laptop' 30)$(mark "$active" extend-above)"      "layout:extend:above"
    item "󰹑   $(pad 'Mirror (same picture)' 30)$(mark "$active" mirror)"            "layout:mirror"
    item "󰐯   $(pad 'External only (present)' 30)$(mark "$active" external)"        "layout:external"
    for o in "${ext[@]}"; do
        item "󰍹   $(pad "$o" 30)$(dim "${CUR[$o]/-/off}  ›")" "out:$o"
    done
fi
item "󰒓   Advanced (arandr)" "arandr"
item "󰑐   Refresh" "refresh"
exit 0
