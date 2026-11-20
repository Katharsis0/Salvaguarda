#!/bin/bash
# rofi script-mode tab "DEVICES" of the Super+Space launcher (rofi type-6).
# Apple-style Bluetooth: no list of old devices, just
#   * connected devices, with battery   -> select: Disconnect / Forget
#   * devices that are on and nearby, closest first -> select: Connect
#     (pairs + trusts automatically if needed; if a paired device refuses
#     the old key, e.g. a keyboard that was re-paired elsewhere, it is
#     forgotten and paired again)
#   * Refresh, Turn Bluetooth off
#
# "Nearby" needs a scan running: launcher.sh starts one when Super+Space
# opens and stops it when rofi closes (BlueZ only reports signal strength
# while some client is scanning). rofi runs this script as soon as the
# launcher opens, so the first listing never waits; "Refresh" picks up
# devices found since.
#
# The menu stays open after every action (Esc closes it). Connecting runs in
# the background (the menu waits up to 5 s for it); the result shows in the
# message box above the list and as a notification.
# BT_FAKE="Name|icon|pct ..." previews connected-device rows (no actions);
# a pct like "80+" previews a charging device.

NID=91920
MIN_RSSI=-95                       # weaker than this = not really "nearby"
SCAN_STAMP="${XDG_RUNTIME_DIR:-/tmp}/bt_scan_started"
STATUS="${XDG_RUNTIME_DIR:-/tmp}/bt_status"   # "busy|text" or "done|text"

# bluetoothctl sprinkles colour codes into its output; strip them
bluetoothctl() { command bluetoothctl "$@" | sed 's/\x1b\[[0-9;]*m//g'; }
notify() { dunstify -r $NID -i bluetooth "$@" >/dev/null 2>&1; }

# Rows are buffered (bash strings can't hold \0: stored as TEXT<RS>KEY<US>VAL)
ROWS=()
opt()  { printf '\0%s\x1f%s\n' "$1" "$2"; }
item() { ROWS+=("$1"$'\x1e'"info"$'\x1f'"$2"); }
flush() { (( ${#ROWS[@]} )) && printf '%s\n' "${ROWS[@]}" | tr '\036' '\000'; }

glyph() {
    case "$1" in
        audio-headset|audio-headphones) echo "󰋋" ;;
        audio-card|audio-speakers)      echo "󰓃" ;;
        input-mouse)                    echo "󰍽" ;;
        input-keyboard)                 echo "󰌌" ;;
        input-gaming)                   echo "󰊴" ;;
        input-tablet)                   echo "󰓶" ;;
        phone)                          echo "󰏲" ;;
        computer)                       echo "󰌢" ;;
        *)                              echo "󰂯" ;;
    esac
}

esc() { local s=${1//&/&amp;}; s=${s//</&lt;}; echo "${s//>/&gt;}"; }
field() { sed -n "s/^\s*$1: //p" <<<"$2" | head -n1; }
# pad/truncate to N *characters* (printf pads bytes, which breaks on ’ é …)
pad() { local s=${1:0:$2}; printf '%s%*s' "$s" $(( $2 - ${#s} )) ''; }
dim() { printf '<span alpha="55%%">%s</span>' "$1"; }

batt_icon() {  # battery glyph for a percentage (same set as polybar)
    local icons=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹) i=$(( $1 / 10 ))
    (( i > 10 )) && i=10
    echo "${icons[$i]}"
}

battery_row() {  # NAME ICON "PCT [charging]" INFO
    local g name color chg=0
    [[ "$3" == *charging ]] && chg=1
    set -- "$1" "$2" "${3%% *}" "$4"
    g=$(glyph "$2"); name=$(esc "$1")
    if [ -z "$3" ]; then
        item "$(printf '%s   %s %s' "$g" "$(pad "$name" 32)" "$(dim connected)")" "$4"
        return
    fi
    if   (( $3 <= 15 )); then color="#E06C75"
    elif (( $3 <= 40 )); then color="#E5C07B"
    else                      color="#98C379"; fi
    item "$(printf '%s   %s <span color="%s">%s  %3d%%</span>' \
        "$g" "$(pad "$name" 32)" "$color" "$( ((chg)) && echo 󰂄 || batt_icon "$3")" "$3")" "$4"
}

name_of() {
    local info n; info=$(bluetoothctl info "$1" 2>/dev/null)
    n=$(field Alias "$info"); [ -z "$n" ] && n=$(field Name "$info")
    echo "${n:-$1}"
}

# Battery: BlueZ knows it for BLE devices and headsets; classic Bluetooth
# keyboards/mice report it through HID instead, which the kernel exposes as
# /sys/class/power_supply/hid-<mac>-battery*.
battery_of() {  # MAC INFO
    # prints "PCT" or "PCT charging"
    local p f d
    p=$(sed -n 's/^\s*Battery Percentage: .*(\([0-9]*\)).*/\1/p' <<<"$2" | head -n1)
    for d in /sys/class/power_supply/hid-"${1,,}"-battery*; do
        [ -r "$d/capacity" ] || continue
        [ -z "$p" ] && p=$(cat "$d/capacity" 2>/dev/null)
        # only if the device actually reports it (many keyboards never do)
        grep -qxE 'Charging|Full' "$d/status" 2>/dev/null && p+=" charging"
        break
    done
    # Most devices never say they're charging; guess from UPower's history
    # instead: last change in level was a rise, within the last hour.
    [ -n "$p" ] && [[ "$p" != *charging ]] && (( p < 100 )) && rising "$1" && p+=" charging"
    echo "$p"
}

# UPower object for a Bluetooth MAC (HID batteries: ...hid_dco2co26...,
# BlueZ batteries: ..._dev_DC_2C_26...)
upower_dev() {
    local m=${1,,}; m=${m//:/o}
    local M=${1^^}; M=${M//:/_}
    upower -e 2>/dev/null | grep -m1 -E "hid_${m}_|_dev_${M}$"
}

rising() {  # MAC -> success if the battery level's last change was upward, <1 h ago
    local dev; dev=$(upower_dev "$1") || return 1
    busctl call org.freedesktop.UPower "$dev" org.freedesktop.UPower.Device \
        GetHistory suu charge 7200 200 2>/dev/null | awk -v now="$(date +%s)" '
        { for (i = 3; i + 2 <= NF; i += 3) if ($(i+1) > 0) print $i, $(i+1) }' |
    sort -n | awk -v now="$(date +%s)" '
        { if (n && $2 != last) { dir = ($2 > last) ? 1 : -1; when = $1 }
          last = $2; n++ }
        END { exit !(dir == 1 && now - when < 3600) }'
}

powered() { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }

# ------------------------------------------------------------ background jobs
bg_job() {  # bg_job verb MAC
    local verb=$1 mac=$2
    setsid -f bash -c '
        bluetoothctl() { command bluetoothctl "$@" | sed "s/\x1b\[[0-9;]*m//g"; }
        notify() { dunstify -r '$NID' -i bluetooth "$@" >/dev/null 2>&1; }
        verb=$1 mac=$2 name=$3 STATUS=$4
        status() { printf "%s|%s" "$1" "$2" > "$STATUS"; }   # shown in the menu

        connect() { bluetoothctl --timeout 15 connect "$mac" 2>&1 | grep -q "Connection successful"; }
        pair() {  # fresh pairing; NoInputNoOutput = no PIN/passkey prompts
            bluetoothctl --agent NoInputNoOutput --timeout 25 pair "$mac" 2>&1 \
                | grep -qE "Pairing successful|AlreadyExists" || return 1
            bluetoothctl trust "$mac" >/dev/null 2>&1
            connect
        }
        paired() { bluetoothctl info "$mac" | grep -q "^\s*Paired: yes"; }

        case $verb in
          connect)
            status busy "Connecting to $name…"
            notify "Bluetooth" "Connecting to $name…"
            if paired; then
                bluetoothctl trust "$mac" >/dev/null 2>&1
                if connect; then
                    status done "Connected to $name"
                    notify "Bluetooth" "Connected to $name"; exit
                fi
                # The device is on and in range (that is why it was listed),
                # yet refuses: its pairing key no longer matches. Start over.
                status busy "Re-pairing $name… turn on its pairing mode"
                notify "Bluetooth" "Re-pairing $name…
If it has a pairing mode, turn it on now."
                bluetoothctl remove "$mac" >/dev/null 2>&1
                bluetoothctl --timeout 8 scan on >/dev/null 2>&1   # find it again
            fi
            if pair; then
                status done "Connected to $name"
                notify "Bluetooth" "Connected to $name"
            else
                status done "Could not connect to $name — put it in pairing mode and try again"
                notify -u critical "Bluetooth" "Could not connect to $name
Put it in pairing mode and try again."
            fi ;;
        esac' _ "$verb" "$mac" "$(name_of "$mac")" "$STATUS" </dev/null >/dev/null 2>&1
}

set_status() { printf '%s|%s' "$1" "$2" > "$STATUS"; }

# a "busy" status older than a minute belongs to a job that died: drop it
[ -f "$STATUS" ] && [ -n "$(find "$STATUS" -mmin +1 2>/dev/null)" ] && rm -f "$STATUS"

# wait (up to $1 s) for a background connect to finish
wait_job() {
    local i
    for ((i = 0; i < $1 * 4; i++)); do
        [[ "$(cat "$STATUS" 2>/dev/null)" == busy\|* ]] || return 0
        sleep 0.25
    done
}

# ------------------------------------------------------------------ actions
trap flush EXIT
ACTION=${ROFI_INFO:-}
case "$ACTION" in
    power-on)
        rfkill unblock bluetooth 2>/dev/null
        bluetoothctl power on >/dev/null 2>&1
        for _ in 1 2 3 4 5 6; do powered && break; sleep 0.5; done
        powered || notify -u critical "Bluetooth" "Could not turn Bluetooth on"
        # scan for the rest of this launcher session (launcher.sh couldn't: BT was off)
        setsid -f bluetoothctl --timeout 60 scan on </dev/null >/dev/null 2>&1
        date +%s > "$SCAN_STAMP"
        sleep 3
        ;;
    power-off)
        bluetoothctl power off >/dev/null 2>&1
        ;;
    refresh)
        # give a scan that only just started a moment to find things
        started=$(cat "$SCAN_STAMP" 2>/dev/null || echo 0)
        wait=$(( started + 4 - $(date +%s) ))
        (( wait > 0 )) && sleep "$wait"
        wait_job 4
        ;;
    connect:*)
        # runs in the background (pairing can take a while); the menu stays
        # open and shows how it went
        set_status busy "Connecting…"
        bg_job connect "${ACTION#*:}"
        sleep 0.3; wait_job 5
        ;;
    disconnect:*)
        mac=${ACTION#*:}; name=$(name_of "$mac")
        bluetoothctl --timeout 10 disconnect "$mac" >/dev/null 2>&1
        set_status done "Disconnected $name"
        ;;
    forget:*)
        mac=${ACTION#*:}; name=$(name_of "$mac")
        bluetoothctl remove "$mac" >/dev/null 2>&1
        set_status done "Forgot $name"
        ;;
    dev:*)
        mac=${ACTION#dev:}
        opt no-custom true; opt markup-rows true
        name=$(esc "$(name_of "$mac")")
        item "󰂲   Disconnect $name"  "disconnect:$mac"
        item "󰆴   Forget $name"      "forget:$mac"
        item "󰁍   Back"              "refresh"
        exit 0
        ;;
esac

# ------------------------------------------------------------------ list
opt no-custom true
opt markup-rows true
# keep the highlight where it was after an action (instead of jumping to top)
[ -n "$ACTION" ] && opt keep-selection true

# status of the last action, shown in the message box above the list
if [ -n "$ACTION" ] && [ -f "$STATUS" ]; then
    IFS='|' read -r st text < "$STATUS"
    if [ "$st" = busy ]; then
        opt message "󰑐  $(esc "$text")  <span alpha='55%'>— select Refresh to update</span>"
    else
        opt message "$(esc "$text")"
        rm -f "$STATUS"
    fi
fi

if [ -n "${BT_FAKE:-}" ]; then
    for d in $BT_FAKE; do
        IFS='|' read -r name icon pct <<<"$d"; pct=${pct//+/ charging}
        battery_row "${name//_/ }" "$icon" "$pct" "refresh"
    done
    exit 0
fi

if ! powered; then
    item "󰂯   Turn Bluetooth on" "power-on"
    exit 0
fi

# connected (with battery)
declare -A IS_CONN
while read -r _ mac _; do
    IS_CONN[$mac]=1
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    name=$(field Alias "$info"); [ -z "$name" ] && name=$(field Name "$info")
    pct=$(battery_of "$mac" "$info")
    battery_row "${name:-$mac}" "$(field Icon "$info")" "$pct" "dev:$mac"
done < <(bluetoothctl devices Connected 2>/dev/null)

# nearby: anything (paired or not) the running scan can currently hear,
# with a real name, strongest signal first
nearby=()
while read -r _ mac name; do
    [ -n "${IS_CONN[$mac]:-}" ] && continue
    [[ -z "$name" || "$name" =~ ^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$ ]] && continue
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    rssi=$(grep -oP 'RSSI: (0x[0-9a-f]+ \()?\K-?[0-9]+' <<<"$info" | head -n1)
    [ -z "$rssi" ] && continue                     # not heard right now
    (( rssi < MIN_RSSI )) && continue
    alias=$(field Alias "$info"); [ -n "$alias" ] && name=$alias
    nearby+=("$(( -rssi ))"$'\t'"$(printf '%s   %s %s' \
        "$(glyph "$(field Icon "$info")")" "$(pad "$(esc "$name")" 32)" "$(dim connect)")"$'\t'"connect:$mac")
done < <(bluetoothctl devices 2>/dev/null)
while IFS=$'\t' read -r _ text info; do
    [ -n "$text" ] && item "$text" "$info"
done < <(printf '%s\n' "${nearby[@]}" | sort -n)

if (( ${#IS_CONN[@]} == 0 && ${#nearby[@]} == 0 )); then
    item "󰑐   Looking for devices… select to refresh" "refresh"
else
    item "󰑐   Refresh" "refresh"
fi
item "󰂲   Turn Bluetooth off" "power-off"
exit 0
