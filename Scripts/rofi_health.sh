#!/bin/bash
# rofi script-mode tab "HEALTH" of the Super+Space launcher (rofi type-6).
# A quick system check-up, problems first:
#   pacman : pending updates (repo + AUR), last full upgrade, last repo sync,
#            mirrorlist age, database lock / consistency, orphans,
#            .pacnew/.pacsave files, package cache size
#   system : reboot needed (kernel upgraded), failed services, disk space,
#            memory, battery wear, temperature, time sync, errors in the
#            journal, hibernation and fingerprint readiness
# Selecting a problem opens a terminal that shows details / the fix.
#
# rofi runs this as soon as the launcher opens, so it never waits: it prints
# the last report (~/.cache/health/report) and refreshes it in the background.
# "Refresh" shows the new one. Pending updates are found like checkupdates
# does (a private copy of the sync databases, refreshed at most hourly), so
# the real pacman database is never touched.
#   rofi_health.sh --collect [--updates]   build the report (what the tab runs)
#   rofi_health.sh --print                 plain-text report in the terminal

CACHE="$HOME/.cache/health"
REPORT="$CACHE/report"            # lines: severity<TAB>icon<TAB>text<TAB>action
UPD="$CACHE/updates"              # "time repo aur" + lists in updates.repo / updates.aur
UPD_MAX_AGE=3600
mkdir -p "$CACHE"

now=$(date +%s)
ago() {  # seconds -> "3 h ago"
    local s=$1
    if   (( s < 90 ));     then echo "just now"
    elif (( s < 5400 ));   then echo "$(( s / 60 )) min ago"
    elif (( s < 172800 )); then echo "$(( s / 3600 )) h ago"
    else                        echo "$(( s / 86400 )) days ago"; fi
}
logtime() {  # epoch of the last pacman.log line matching $1 (or empty)
    local t; t=$(grep -F "$1" /var/log/pacman.log 2>/dev/null | tail -n1 | grep -oP '^\[\K[^]]+')
    [ -n "$t" ] && date -d "$t" +%s 2>/dev/null
}

# ------------------------------------------------------------------ updates
check_updates() {  # slow (network): repo updates via a private db copy + AUR
    exec 7>"$CACHE/.updates.lock"; flock -n 7 || return 0
    local db="$CACHE/pacman-db" repo aur
    mkdir -p "$db/sync"
    ln -sfn /var/lib/pacman/local "$db/local"
    cp -p /var/lib/pacman/sync/*.db "$db/sync/" 2>/dev/null   # start from the current state
    if timeout 60 fakeroot -- pacman -Sy --disable-sandbox --dbpath "$db" --logfile /dev/null >/dev/null 2>&1; then
        pacman -Qu --dbpath "$db" 2>/dev/null > "$CACHE/updates.repo"
        repo=$(grep -c . "$CACHE/updates.repo")
    else
        repo="?"
    fi
    if command -v paru >/dev/null && timeout 30 paru -Qua 2>/dev/null > "$CACHE/updates.aur.tmp"; then
        mv "$CACHE/updates.aur.tmp" "$CACHE/updates.aur"; aur=$(grep -c . "$CACHE/updates.aur")
    else
        rm -f "$CACHE/updates.aur.tmp"; aur="?"
    fi
    echo "$(date +%s) $repo $aur" > "$UPD"
}

# ------------------------------------------------------------------ report
collect() {
    local out=() sev icon txt
    add() { out+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"${4:-}"); }   # sev: 0 error, 1 warning, 2 info, 3 ok

    # --- pacman ---
    if [ -f "$UPD" ]; then
        local t repo aur; read -r t repo aur < "$UPD"
        if [ "$repo" = "?" ]; then
            add 1 "󰚰" "Updates: couldn't check (offline?)" refresh-updates
        elif (( repo + ${aur//\?/0} > 0 )); then
            local parts=(); (( repo > 0 )) && parts+=("$repo repo"); [ "${aur:-0}" != 0 ] && parts+=("$aur AUR")
            add 1 "󰚰" "Updates: ${parts[*]} waiting" upgrade
        else
            add 3 "󰚰" "Up to date (checked $(ago $(( now - t ))))" refresh-updates
        fi
    else
        add 2 "󰚰" "Checking for updates…" refresh
    fi

    local up sync d
    up=$(logtime 'starting full system upgrade')
    if [ -n "$up" ]; then d=$(( (now - up) / 86400 ))
        (( d >= 14 )) && sev=1 || sev=3
        add $sev "󰏗" "Last full upgrade: $(ago $(( now - up )))" upgrade
    fi
    sync=$(logtime 'synchronizing package lists')
    [ -n "$sync" ] && add 3 "󰓦" "Repositories last synced: $(ago $(( now - sync )))"

    d=$(( (now - $(stat -c %Y /etc/pacman.d/mirrorlist)) / 86400 ))
    if (( d > 90 )); then
        add 1 "󰒍" "Mirror list is $d days old" mirrors
    else
        add 3 "󰒍" "Mirror list: updated $d days ago"
    fi

    if [ -e /var/lib/pacman/db.lck ] && ! pgrep -x 'pacman|paru|yay' >/dev/null; then
        add 0 "󰌾" "Stale pacman lock" lock
    fi
    if pacman -Dk >/dev/null 2>&1; then
        add 3 "󰆼" "Package database: consistent"
    else
        add 0 "󰆼" "Package db: broken dependencies" dbcheck
    fi

    local orphans; orphans=$(pacman -Qdtq 2>/dev/null | grep -c .)
    (( orphans > 0 )) && add 2 "󰆴" "$orphans orphaned packages" orphans \
                      || add 3 "󰆴" "No orphaned packages"

    local pacnew; pacnew=$(find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null | grep -c .)
    (( pacnew > 0 )) && add 1 "󰈙" "$pacnew .pacnew files to review" pacnew \
                     || add 3 "󰈙" "No pending .pacnew config files"

    local cache_kb; cache_kb=$(du -sk /var/cache/pacman/pkg 2>/dev/null | cut -f1)
    if (( ${cache_kb:-0} > 5 * 1024 * 1024 )); then
        add 1 "󰃢" "Package cache: $(( cache_kb / 1024 / 1024 )) GB" cache
    else
        add 3 "󰃢" "Package cache: $(( ${cache_kb:-0} / 1024 )) MB"
    fi

    # --- system ---
    [ -d "/usr/lib/modules/$(uname -r)" ] \
        || add 1 "󰜉" "Reboot needed (kernel upgraded)" reboot

    local failed; failed=$( { systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain; } 2>/dev/null | awk '{print $1}')
    if [ -n "$failed" ]; then
        add 0 "󰒏" "Failed: $(echo $failed | sed 's/\.service//g; s/ /, /g')" failed
    else
        add 3 "󰒏" "All services running"
    fi

    local m pct avail
    while read -r m pct avail; do
        pct=${pct%\%}
        if   (( pct >= 95 )); then sev=0; elif (( pct >= 85 )); then sev=1; else sev=3; fi
        add $sev "󰋊" "Disk $m: ${pct}% used, $avail free" $( (( sev < 3 )) && echo disk )
    done < <(df -h --output=target,pcent,avail / /home 2>/dev/null | tail -n +2 | sort -u -k1,1)

    local mem; mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d %.1f", 100-a*100/t, a/1048576}' /proc/meminfo)
    read -r pct avail <<<"$mem"
    (( pct >= 90 )) && sev=1 || sev=3
    add $sev "󰍛" "Memory: ${pct}% used, ${avail} GB available"

    local b full design
    for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/energy_full" ] || continue
        full=$(cat "$b/energy_full"); design=$(cat "$b/energy_full_design")
        pct=$(( full * 100 / design ))
        (( pct < 50 )) && sev=1 || sev=2
        add $sev "󰁹" "$(basename "$b") health: ${pct}% of original"
    done

    local temp; temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -n1)
    if [ -n "$temp" ]; then temp=$(( temp / 1000 ))
        (( temp >= 85 )) && sev=1 || sev=3
        add $sev "󰔏" "Temperature: ${temp} °C"
    fi

    if [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" = yes ]; then
        add 3 "󰥔" "Clock synchronized"
    else
        add 1 "󰥔" "Clock not synchronized" ntp
    fi

    local errs; errs=$(journalctl -p 3 -b -q --no-pager 2>/dev/null | grep -c .)
    (( errs > 50 )) && sev=1 || sev=2
    add $sev "󰀪" "$errs errors in the log since boot" journal

    if busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null | grep -q '"yes"'; then
        add 3 "󰒲" "Hibernation ready"
    else
        add 1 "󰒲" "Hibernation not available"
    fi
    if systemctl is-active -q python3-validity open-fprintd 2>/dev/null; then
        add 3 "󰈷" "Fingerprint sensor ready"
    else
        add 1 "󰈷" "Fingerprint service down" fprint
    fi

    printf '%s\n' "${out[@]}" | sort -s -t$'\t' -k1,1n > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"
}

refresh_bg() {  # rebuild the report (and the update check if stale) in the background
    local force_upd=$1 t=0
    [ -f "$UPD" ] && read -r t _ < "$UPD"
    (
        exec 8>"$CACHE/.collect.lock"; flock -n 8 || exit 0
        collect
        if [ "$force_upd" = 1 ] || (( now - t > UPD_MAX_AGE )); then check_updates; collect; fi
    ) >/dev/null 2>&1 &
    disown
}

# ------------------------------------------------------------------ actions
term() {  # run a command in a terminal that stays open
    setsid -f alacritty --title "System health" -e bash -c "$1"'; echo; read -rp "Press Enter to close… "' >/dev/null 2>&1
}
do_action() {
    case "$1" in
        upgrade)  term 'echo "Pending repo updates:"; cat ~/.cache/health/updates.repo; echo; echo "Pending AUR updates:"; cat ~/.cache/health/updates.aur 2>/dev/null; echo; paru -Syu' ;;
        mirrors)  term 'echo "Refresh the mirror list with reflector (fastest recent HTTPS mirrors):"; echo; echo "  sudo pacman -S --needed reflector"; echo "  sudo reflector --country US,MX --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist"; echo; read -rp "Run it now? [y/N] " r; [[ $r == [yYsS]* ]] && sudo pacman -S --needed reflector && sudo reflector --country US,MX --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist' ;;
        lock)     term 'echo "No pacman is running, so the lock is left over from a crash."; echo "Remove it with:  sudo rm /var/lib/pacman/db.lck"; read -rp "Remove now? [y/N] " r; [[ $r == [yYsS]* ]] && sudo rm /var/lib/pacman/db.lck' ;;
        dbcheck)  term 'pacman -Dk' ;;
        orphans)  term 'pacman -Qdt; echo; read -rp "Remove them all (sudo pacman -Rns)? [y/N] " r; [[ $r == [yYsS]* ]] && sudo pacman -Rns $(pacman -Qdtq)' ;;
        pacnew)   term 'find /etc \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null; echo; echo "Compare each with the original (e.g. diff /etc/x /etc/x.pacnew), merge what you want, then delete the .pacnew."' ;;
        cache)    term 'du -sh /var/cache/pacman/pkg; echo; echo "Keeps only the installed version of each package and empties the AUR build cache:"; echo "  paru -Sc"; echo; read -rp "Run it now? [y/N] " r; [[ $r == [yYsS]* ]] && paru -Sc' ;;
        reboot)   setsid -f ~/.config/rofi/powermenu/type-2/powermenu.sh >/dev/null 2>&1 ;;
        failed)   term 'systemctl --failed; systemctl --user --failed' ;;
        disk)     term 'df -h / /home; echo; echo "Biggest folders in your home:"; du -xh --max-depth=1 ~ 2>/dev/null | sort -h | tail -12' ;;
        ntp)      term 'timedatectl; echo; echo "Turn it on with: sudo timedatectl set-ntp true"' ;;
        journal)  term 'journalctl -p 3 -b --no-pager | tail -n 60' ;;
        fprint)   term 'systemctl status python3-validity open-fprintd --no-pager; echo; echo "Restart with: sudo systemctl restart python3-validity open-fprintd"' ;;
    esac
}

# ------------------------------------------------------------------ entry
case "${1:-}" in
    --collect) [ "${2:-}" = --updates ] && check_updates; collect; exit 0 ;;
    --print)   collect; awk -F'\t' '{ s = ($1==0) ? "ERROR" : ($1==1) ? "WARN " : ($1==2) ? "info " : "ok   "; print s "  " $3 }' "$REPORT"; exit 0 ;;
esac

ACTION=${ROFI_INFO:-}
case "$ACTION" in
    refresh)         collect ;;                       # fast checks now, list redrawn below
    none)            ;;                               # info-only row: stay open
    refresh-updates) collect; refresh_bg 1 ;;
    "")              ;;
    *)               do_action "$ACTION"; exit 0 ;;   # opened a terminal: close rofi
esac
[ -z "$ACTION" ] && refresh_bg 0

printf '\0no-custom\x1ftrue\n\0markup-rows\x1ftrue\n'
[ -n "$ACTION" ] && printf '\0keep-selection\x1ftrue\n'

if [ ! -s "$REPORT" ]; then
    printf '\0message\x1f%s\n' "Checking the system for the first time…"
    printf '%s\0info\x1frefresh\n' "󰑐   Refresh"
    exit 0
fi

errs=$(awk -F'\t' '$1==0' "$REPORT" | grep -c .); warns=$(awk -F'\t' '$1==1' "$REPORT" | grep -c .)
age=$(( now - $(stat -c %Y "$REPORT") ))
if (( errs + warns == 0 )); then summary="󰄬  All good"
else summary="$( (( errs )) && printf '%d problem%s  ' $errs "$( (( errs > 1 )) && echo s)")$( (( warns )) && printf '%d warning%s' $warns "$( (( warns > 1 )) && echo s)")"; fi
printf '\0message\x1f%s\n' "$summary  <span alpha='55%'>· checked $(ago $age) · select a row for details</span>"

esc() { local s=${1//&/&amp;}; s=${s//</&lt;}; echo "${s//>/&gt;}"; }
while IFS=$'\t' read -r sev icon text action; do
    case $sev in
        0) row="<span foreground='#D14D4D'>$icon</span>   $(esc "$text")" ;;
        1) row="<span foreground='#D08A1E'>$icon</span>   $(esc "$text")" ;;
        2) row="$icon   $(esc "$text")" ;;
        *) row="<span alpha='55%'>$icon   $(esc "$text")</span>" ;;
    esac
    printf '%s\0info\x1f%s\n' "$row" "${action:-none}"
done < "$REPORT"
printf '%s\0info\x1frefresh\n' "󰑐   Refresh"
