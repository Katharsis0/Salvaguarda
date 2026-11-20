#!/bin/bash
# rofi script-mode tab "DEVICES" of the Super+Space launcher (rofi type-6):
# Bluetooth control + battery levels.
#
#   Bluetooth off   -> "Turn Bluetooth on"
#   Connected       -> name + battery bar; select -> submenu (disconnect)
#   Paired          -> select to connect
#   Nearby          -> devices in range that aren't paired; select to pair,
#                      trust and connect (put the device in pairing mode)
#   Scan / Refresh, Turn Bluetooth off
#
# Slow actions (connect/pair/disconnect) run in the background, close the
# menu and report through notifications.
# Battery comes from BlueZ (Battery1: BLE battery service, or headsets that
# report it over HFP via PipeWire). Devices that don't report it say so.
#
# BT_FAKE="Name|icon|pct ..." previews the connected-device rows (no actions).

NID=91920
# bluetoothctl sprinkles colour codes into its output; strip them
bluetoothctl() { command bluetoothctl "$@" | sed 's/\x1b\[[0-9;]*m//g'; }
notify() { dunstify -r $NID -i bluetooth "$@" >/dev/null 2>&1; }

# Rows are buffered so the initial highlight can skip the section headers.
ROWS=(); FIRST=-1
opt()  { printf '\0%s\x1f%s\n' "$1" "$2"; }               # rofi mode option
# (bash strings can't hold \0, so rows are stored as TEXT<RS>KEY<US>VALUE)
item() { (( FIRST < 0 )) && FIRST=${#ROWS[@]}               # selectable row
         ROWS+=("$1"$'\x1e'"info"$'\x1f'"$2"); }
note() { ROWS+=("$1"$'\x1e'"nonselectable"$'\x1f'"true"); }
# No header rows: rofi always highlights row 0 on open, and a header there
# makes Enter do nothing. Rows describe themselves (battery / connect / pair).
head_() { :; }
flush() { (( FIRST > 0 )) && opt new-selection "$FIRST"
          (( ${#ROWS[@]} )) && printf '%s\n' "${ROWS[@]}" | tr '\036' '\000'; }
trap flush EXIT

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

bar() {  # 10-cell bar for a percentage
    local n=$(( ($1 + 5) / 10 )) s="" i
    (( n > 10 )) && n=10
    for ((i = 0; i < 10; i++)); do (( i < n )) && s+="■" || s+="□"; done
    echo "$s"
}

battery_row() {  # NAME ICON PCT INFO
    local g name color
    g=$(glyph "$2"); name=$(esc "$1")
    if [ -z "$3" ]; then
        item "$(printf '%s   %-32.32s <i>no battery info</i>' "$g" "$name")" "$4"
        return
    fi
    if   (( $3 <= 15 )); then color="#E06C75"
    elif (( $3 <= 40 )); then color="#E5C07B"
    else                      color="#98C379"; fi
    item "$(printf '%s   %-32.32s <span color="%s">%s</span>  %3d%%' \
        "$g" "$name" "$color" "$(bar "$3")" "$3")" "$4"
}

field() { sed -n "s/^\s*$1: //p" <<<"$2" | head -n1; }

name_of() {
    local info n; info=$(bluetoothctl info "$1" 2>/dev/null)
    n=$(field Alias "$info"); [ -z "$n" ] && n=$(field Name "$info")
    echo "${n:-$1}"
}

# run a slow bluetoothctl job in the background, with notifications
bg_job() {  # bg_job verb MAC
    local verb=$1 mac=$2 name
    name=$(name_of "$mac")
    setsid -f bash -c '
        notify() { dunstify -r '$NID' -i bluetooth "$@" >/dev/null 2>&1; }
        verb=$1 mac=$2 name=$3
        case $verb in
          connect)
            notify "Bluetooth" "Connecting to $name…"
            out=$(bluetoothctl --timeout 15 connect "$mac" 2>&1)
            if grep -q "Connection successful" <<<"$out"; then
                notify "Bluetooth" "Connected to $name"
            else
                notify -u critical "Bluetooth" "Could not connect to $name
Is it on and in range?"
            fi ;;
          disconnect)
            bluetoothctl --timeout 10 disconnect "$mac" >/dev/null 2>&1
            notify "Bluetooth" "Disconnected $name" ;;
          pair)
            notify "Bluetooth" "Pairing with $name…
Make sure it is in pairing mode."
            bluetoothctl --timeout 5 scan off >/dev/null 2>&1
            out=$(bluetoothctl --timeout 25 pair "$mac" 2>&1)
            if grep -qE "Pairing successful|AlreadyExists" <<<"$out"; then
                bluetoothctl trust "$mac" >/dev/null 2>&1
                out=$(bluetoothctl --timeout 15 connect "$mac" 2>&1)
                if grep -q "Connection successful" <<<"$out"; then
                    notify "Bluetooth" "Paired and connected to $name"
                else
                    notify "Bluetooth" "Paired with $name (select it again to connect)"
                fi
            else
                notify -u critical "Bluetooth" "Pairing with $name failed
Put it in pairing mode and try again."
            fi ;;
        esac' _ "$verb" "$mac" "$name" </dev/null >/dev/null 2>&1
}

powered() { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }

# ------------------------------------------------------------------ actions
ACTION=${ROFI_INFO:-}
case "$ACTION" in
    power-on)
        rfkill unblock bluetooth 2>/dev/null
        bluetoothctl power on >/dev/null 2>&1
        for _ in 1 2 3 4 5 6; do powered && break; sleep 0.5; done
        powered || notify -u critical "Bluetooth" "Could not turn Bluetooth on"
        ;;
    power-off)
        bluetoothctl power off >/dev/null 2>&1
        ;;
    scan)
        setsid -f bluetoothctl --timeout 30 scan on </dev/null >/dev/null 2>&1
        sleep 4      # give nearby devices a moment to show up
        ;;
    connect:*|disconnect:*|pair:*)
        bg_job "${ACTION%%:*}" "${ACTION#*:}"
        exit 0       # no output -> rofi closes; notifications take over
        ;;
    dev:*)
        mac=${ACTION#dev:}
        opt no-custom true; opt markup-rows true
        item "󰂲   Disconnect $(esc "$(name_of "$mac")")"  "disconnect:$mac"
        item "󰁍   Back"        "refresh"
        exit 0
        ;;
esac

# ------------------------------------------------------------------ list
opt no-custom true
opt markup-rows true

if [ -n "${BT_FAKE:-}" ]; then
    head_ "Connected"
    for d in $BT_FAKE; do
        IFS='|' read -r name icon pct <<<"$d"
        battery_row "${name//_/ }" "$icon" "$pct" "refresh"
    done
    exit 0
fi

if ! powered; then
    item "󰂯   Turn Bluetooth on" "power-on"
    exit 0
fi

declare -A PAIRED IS_CONN
while read -r _ mac _; do PAIRED[$mac]=1; done < <(bluetoothctl devices Paired 2>/dev/null)
connected=()
while read -r _ mac _; do connected+=("$mac"); IS_CONN[$mac]=1; done \
    < <(bluetoothctl devices Connected 2>/dev/null)

head_ "Connected"
for mac in "${connected[@]}"; do
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    name=$(field Alias "$info"); [ -z "$name" ] && name=$(field Name "$info")
    pct=$(sed -n 's/^\s*Battery Percentage: .*(\([0-9]*\)).*/\1/p' <<<"$info" | head -n1)
    battery_row "${name:-$mac}" "$(field Icon "$info")" "$pct" "dev:$mac"
done

# rows "TEXT<TAB>INFO", sorted by name, under a header
section() {  # section TITLE ROWS...
    local title=$1; shift
    (( $# )) || return 0
    head_ "$title"
    while IFS=$'\t' read -r text info; do item "$text" "$info"; done < <(printf '%s\n' "$@" | sort)
}

paired_rows=()
for mac in "${!PAIRED[@]}"; do
    [ -n "${IS_CONN[$mac]:-}" ] && continue
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    name=$(field Alias "$info"); [ -z "$name" ] && name=$(field Name "$info")
    paired_rows+=("$(printf '%s   %-32.32s <span alpha="55%%">connect</span>' \
        "$(glyph "$(field Icon "$info")")" "$(esc "${name:-$mac}")")"$'\t'"connect:$mac")
done
section "Paired" "${paired_rows[@]}"

# nearby: discovered, not paired, currently in range (has RSSI), real name
nearby=()
while read -r _ mac name; do
    [ -n "${PAIRED[$mac]:-}" ] && continue
    [[ -z "$name" || "$name" =~ ^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$ ]] && continue
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    grep -q 'RSSI:' <<<"$info" || continue
    nearby+=("$(printf '%s   %-32.32s <span alpha="55%%">pair</span>' \
        "$(glyph "$(field Icon "$info")")" "$(esc "$name")")"$'\t'"pair:$mac")
done < <(bluetoothctl devices 2>/dev/null)
section "Nearby" "${nearby[@]}"

head_ " "
if bluetoothctl show 2>/dev/null | grep -q 'Discovering: yes'; then
    item "󰑐   Scanning… select to refresh" "refresh"
else
    item "󰂰   Scan for nearby devices" "scan"
fi
item "󰂲   Turn Bluetooth off" "power-off"
exit 0
