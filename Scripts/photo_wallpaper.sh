#!/usr/bin/env bash
# Rotating photo wallpapers, one set per theme mode, new photo every day,
# plus an accent colour (polybar, i3 title bars, Alacritty cursor, lock screen)
# taken from each photo.
#
#   dark  -> astronomy (Wikimedia Commons "Featured pictures of astronomy"),
#            bright photos skipped and the rest dimmed for night use
#   light -> animals   (Wikimedia Commons "Featured pictures of animals"),
#            used as-is
#
# Usage:
#   photo_wallpaper.sh            rotate any set whose photo is >= 1 day old
#   photo_wallpaper.sh --new      new photo for the active mode now, with
#                                 on-screen progress (Super+O menu)
#   photo_wallpaper.sh --force [dark|light]   new photo now, no notification
#   photo_wallpaper.sh --daemon   loop forever, checking every hour (started from i3)
#   photo_wallpaper.sh --revert   active mode: swap back to the previous photo
#   photo_wallpaper.sh --info     show both sets' photos and authors
#
# Commons photos are freely licensed (mostly CC BY-SA: credit the author), so
# the author/license is shown in the notification and in --info. Public API,
# no key. (Unsplash's API terms don't allow wallpaper apps.)
#
# Cache: ~/.cache/wallpapers/<mode>/ (never committed)
#   current.{jpg,json,accent}   on screen     previous.{jpg,json,accent}  reserve
#   last_try (offline throttle)   too_bright (dark set: rejected photo ids)
# Fallbacks: offline / bad download -> keep current; current broken ->
# previous; nothing at all -> theme.sh uses the bundled desktop_bgs image.

DOTFILES="$HOME/GitHub/dotfiles"
ROOT="$HOME/.cache/wallpapers"
MAX_AGE=$((24 * 3600))       # one new photo a day
RETRY_AFTER=$((3 * 3600))         # offline? try again in 3 h, not every hour
API="https://commons.wikimedia.org/w/api.php"
UA="dotfiles-photo-wallpaper/1.0 (personal desktop wallpaper script; curl)"

# Per-mode settings
set_mode() {
    MODE=$1; DIR="$ROOT/$MODE"; mkdir -p "$DIR"
    if [ "$MODE" = dark ]; then
        # galaxies, nebulae, planets, comets, aurora, spacecraft; minus the
        # poster subcategory and the sunsets/sunrises filed under the Sun
        SEARCH='deepcat:"Featured pictures of astronomy" -deepcat:"Featured pictures of space posters" -intitle:sunset -intitle:sunrise -intitle:dusk -intitle:dawn'
        MAX_TRIES=5        # photos to download looking for a dark-enough one
        MAX_MEAN=0.45      # brighter than this (0 black .. 1 white): skip it
        TARGET_MEAN=0.30   # anything brighter is dimmed down to about this
        LABEL="astronomy"
    else
        SEARCH='deepcat:"Featured pictures of animals"'
        MAX_TRIES=1; MAX_MEAN=1; TARGET_MEAN=1   # no brightness rules
        LABEL="animal"
    fi
}

log() { echo "photo_wallpaper[$MODE]: $*" >&2; }
notify() { command -v notify-send >/dev/null && notify-send -a Wallpaper -i image-x-generic "$@"; }
age_of() { [ -f "$1" ] && echo $(( $(date +%s) - $(stat -c %Y "$1") )) || echo 999999999; }
active_mode() { [ "$(cat "$HOME/.cache/theme_mode" 2>/dev/null)" = light ] && echo light || echo dark; }
caption() { jq -r '"\(.alt_description)\nPhoto: \(.user.name) · \(.license) · Wikimedia Commons"' "$DIR/current.json"; }

apply_if_active() {
    [ "$(active_mode)" = "$MODE" ] || return 0
    # 8>&- 9>&-: theme.sh restarts polybar, which must not inherit our lock
    # fds (a long-lived polybar holding them blocked every later run)
    "$DOTFILES/Scripts/theme.sh" apply >/dev/null 2>&1 8>&- 9>&-
}

# Make sure "current" is usable; otherwise promote the reserve.
heal() {
    if ! magick identify "$DIR/current.jpg" >/dev/null 2>&1 && [ -f "$DIR/previous.jpg" ]; then
        for e in jpg json accent; do [ -f "$DIR/previous.$e" ] && cp "$DIR/previous.$e" "$DIR/current.$e"; done
        log "current photo missing/corrupt, restored the previous one"
    fi
}

fetch() {
    touch "$DIR/last_try" "$DIR/too_bright"

    local sw tw tmp list meta url id
    sw=$(xrandr 2>/dev/null | awk '/current/ {for(i=1;i<=NF;i++) if($i=="current"){print $(i+1); exit}}')
    # Wikimedia only serves standard thumbnail widths
    if [ "${sw:-0}" -gt 1920 ]; then tw=3840; else tw=1920; fi

    tmp=$(mktemp -d "$DIR/.dl.XXXX"); trap 'rm -rf "$tmp"' RETURN
    list="$tmp/list.json"; meta="$tmp/photo.json"
    if ! curl -fsSG -m 25 -A "$UA" "$API" \
            --data-urlencode action=query --data-urlencode format=json \
            --data-urlencode generator=search --data-urlencode gsrnamespace=6 \
            --data-urlencode "gsrsearch=$SEARCH filew:>1900 filetype:bitmap" \
            --data-urlencode gsrsort=random --data-urlencode gsrlimit=30 \
            --data-urlencode prop=imageinfo --data-urlencode "iiprop=url|size|extmetadata" \
            --data-urlencode "iiextmetadatafilter=Artist|LicenseShortName|ObjectName" \
            --data-urlencode "iiurlwidth=$tw" -o "$list"; then
        log "Wikimedia Commons unreachable (offline?); keeping the current wallpaper"
        return 1
    fi

    # Landscape photos (ratio 1.3-2.1: fills the screen without heavy
    # cropping), not already current/previous/rejected, in the random order
    # (the API returns pages alphabetically; .index is the search rank).
    local skip1 skip2
    skip1=$(jq -r '.id // ""' "$DIR/current.json" 2>/dev/null)
    skip2=$(jq -r '.id // ""' "$DIR/previous.json" 2>/dev/null)
    jq --arg s1 "$skip1" --arg s2 "$skip2" --rawfile bright "$DIR/too_bright" '
        [ ([.query.pages[]?] | sort_by(.index))[] | . as $p | .imageinfo[0]
          | select(.width > 0 and (.width / .height) >= 1.3 and (.width / .height) <= 2.1)
          | select($p.title != $s1 and $p.title != $s2)
          | select(($bright | split("\n") | index($p.title)) == null)
          | { id: $p.title,
              url: .thumburl,
              alt_description: ((.extmetadata.ObjectName.value // ($p.title | sub("^File:"; "") | sub("\\.[A-Za-z]+$"; "")))
                                | gsub("<[^>]*>"; "") | gsub("_"; " ")),
              user: { name: ((.extmetadata.Artist.value // "unknown") | gsub("<[^>]*>"; "") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ")) },
              license: (.extmetadata.LicenseShortName.value // ""),
              links: { html: .descriptionurl } } ]' "$list" > "$tmp/cands.json"
    local n; n=$(jq 'length' "$tmp/cands.json" 2>/dev/null)
    [ "${n:-0}" -gt 0 ] || { log "no suitable photo in this batch; will retry later"; return 1; }

    # Take the first photo not brighter than MAX_MEAN (dark set only; the
    # light set accepts the first one), else the darkest one seen.
    local i best="" best_mean=9 mean
    for (( i = 0; i < n && i < MAX_TRIES; i++ )); do
        url=$(jq -r ".[$i].url" "$tmp/cands.json")
        curl -fsSL -m 90 -A "$UA" "$url" -o "$tmp/c$i.jpg" || continue
        mean=$(magick "$tmp/c$i.jpg" -resize 400x -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null) || continue
        if awk -v m="$mean" -v b="$best_mean" 'BEGIN{exit !(m < b)}'; then best=$i; best_mean=$mean; fi
        awk -v m="$mean" -v t="$MAX_MEAN" 'BEGIN{exit !(m <= t)}' && break
        jq -r ".[$i].id" "$tmp/cands.json" >> "$DIR/too_bright"
        log "skipping a bright photo (brightness $mean)"
    done
    [ -n "$best" ] || { log "download failed; keeping the current wallpaper"; return 1; }
    jq ".[$best]" "$tmp/cands.json" > "$meta"
    id=$(jq -r '.id' "$meta")

    # Accent from the untouched photo (truest colours), tuned for this mode's bar.
    "$DOTFILES/Scripts/accent_color.sh" "$tmp/c$best.jpg" "" "$MODE" > "$tmp/photo.accent"
    if awk -v m="$best_mean" -v t="$TARGET_MEAN" 'BEGIN{exit !(m > t)}'; then
        magick "$tmp/c$best.jpg" -evaluate multiply "$(awk -v m="$best_mean" -v t="$TARGET_MEAN" 'BEGIN{printf "%.3f", t/m}')" \
            -quality 92 "$tmp/photo.jpg" || cp "$tmp/c$best.jpg" "$tmp/photo.jpg"
        log "dimmed photo from brightness $best_mean to ~$TARGET_MEAN"
    else
        mv "$tmp/c$best.jpg" "$tmp/photo.jpg"
    fi

    # Rotate: current -> previous (the reserve), new -> current.
    for e in jpg json accent; do [ -f "$DIR/current.$e" ] && mv -f "$DIR/current.$e" "$DIR/previous.$e"; done
    mv -f "$tmp/photo.jpg" "$DIR/current.jpg"
    mv -f "$meta" "$DIR/current.json"
    mv -f "$tmp/photo.accent" "$DIR/current.accent"
    log "new photo $id by $(jq -r '.user.name' "$DIR/current.json"), accent $(cat "$DIR/current.accent")"
}

rotate() {  # rotate MODE FORCE
    set_mode "$1"; heal
    if [ "$2" != 1 ]; then
        [ "$(age_of "$DIR/current.jpg")" -lt "$MAX_AGE" ] && return 1
        [ "$(age_of "$DIR/last_try")" -lt "$RETRY_AFTER" ] && return 1
    fi
    fetch || return 1
    apply_if_active
    [ -n "$QUIET" ] || [ "$(active_mode)" != "$MODE" ] || notify "New wallpaper" "$(caption)"
}

case "$1" in
    --force)  rotate "${2:-$(active_mode)}" 1 ;;
    --new)
        # Interactive: one notification that updates in place.
        set_mode "$(active_mode)"
        exec 8>"$ROOT/.new.lock"; flock -n 8 || exit 0      # ignore double clicks
        nid=$(notify-send -a Wallpaper -i image-x-generic -t 60000 -p "New wallpaper" "Looking for a new $LABEL photo…")
        if err=$(QUIET=1 rotate "$MODE" 1 2>&1 >/dev/null); then
            notify-send -a Wallpaper -i image-x-generic -r "$nid" "New wallpaper" "$(caption)"
        else
            err=$(tail -n1 <<<"$err"); err=${err#*: }
            notify-send -a Wallpaper -i dialog-warning -r "$nid" "Couldn't change the wallpaper" "${err:-unknown error}"
        fi ;;
    --daemon)
        mkdir -p "$ROOT"
        exec 9>"$ROOT/.daemon.lock"; flock -n 9 || exit 0
        # 9>&-: children (sleep, theme.sh -> polybar) must not inherit the lock fd,
        # or a leftover process would block the next daemon from starting
        sleep 20 9>&-                 # let the network come up after login
        while true; do
            rotate "$(active_mode)" 0 9>&-                            # the visible one first
            [ "$(active_mode)" = dark ] && other=light || other=dark
            QUIET=1 rotate "$other" 0 9>&-
            sleep 3600 9>&-
        done ;;
    --revert)
        set_mode "$(active_mode)"
        [ -f "$DIR/previous.jpg" ] || { echo "no previous photo"; exit 1; }
        for e in jpg json accent; do
            [ -f "$DIR/current.$e" ] && mv -f "$DIR/current.$e" "$DIR/swap.$e"
            [ -f "$DIR/previous.$e" ] && mv -f "$DIR/previous.$e" "$DIR/current.$e"
            [ -f "$DIR/swap.$e" ] && mv -f "$DIR/swap.$e" "$DIR/previous.$e"
        done
        touch "$DIR/current.jpg"      # restart the 3-day clock for the restored photo
        apply_if_active ;;
    --info)
        for m in dark light; do
            set_mode $m
            for s in current previous; do
                [ -f "$DIR/$s.jpg" ] || continue
                printf '%-5s %-8s %s  accent %s  %s\n' "$m" "$s" \
                    "$(jq -r '"\(.user.name) — \(.links.html)"' "$DIR/$s.json" 2>/dev/null)" \
                    "$(cat "$DIR/$s.accent" 2>/dev/null)" "$(date -r "$DIR/$s.jpg" '+%F %R')"
            done
        done ;;
    *)  rotate dark 0; rotate light 0 ;;
esac
