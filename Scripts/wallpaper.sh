#!/usr/bin/env bash
# Usage: wallpaper.sh /path/to/image.png
# Builds a single image the size of the whole X screen and places the wallpaper
# on every active output:
#   - horizontal outputs : stretched to fill (previous `feh --bg-scale` behaviour)
#   - vertical outputs   : scaled keeping aspect ratio, letterboxed with $PAD_COLOR
# Falls back to plain `feh --bg-scale` if ImageMagick is unavailable.

IMG="$1"
PAD_COLOR="${PAD_COLOR:-black}"
OUT="$HOME/.cache/wallpaper-composite.png"

[ -f "$IMG" ] || { echo "wallpaper.sh: no such image: $IMG" >&2; exit 1; }

if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
  feh --bg-scale "$IMG"
  exit 0
fi

if command -v magick >/dev/null 2>&1; then IM=(magick); else IM=(convert); fi

SCREEN=$(xrandr --query | awk '/^Screen /{print $8"x"substr($10,1,length($10)-1)}')
[ -z "$SCREEN" ] && { feh --bg-scale "$IMG"; exit 0; }

args=("${IM[@]}" -size "$SCREEN" "xc:$PAD_COLOR")

while read -r w h x y; do
  if [ "$h" -gt "$w" ]; then
    # Vertical monitor: preserve aspect ratio, pad the leftover space
    geom="${w}x${h}"
    args+=( \( "$IMG" -resize "$geom" -background "$PAD_COLOR" -gravity center -extent "$geom" +gravity \) \
            -gravity NorthWest -geometry "+${x}+${y}" -composite )
  else
    # Horizontal monitor: stretch to fill, as before
    args+=( \( "$IMG" -resize "${w}x${h}!" \) -gravity NorthWest -geometry "+${x}+${y}" -composite )
  fi
done < <(xrandr --query | grep -oP '(?<= connected )(primary )?\K[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' \
          | tr 'x+' '   ')

"${args[@]}" "$OUT" || { feh --bg-scale "$IMG"; exit 0; }

feh --no-xinerama --bg-scale "$OUT"
