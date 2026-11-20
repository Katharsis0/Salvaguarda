#!/usr/bin/env bash
# Usage: accent_color.sh IMAGE [FALLBACK_HEX] [dark|light]
# Prints a "#RRGGBB" accent taken from the image's palette, tuned to be
# readable on the polybar background of that mode (dark: #282A2E, light: bone
# #F2EEE6). Dark mode -> light, soft accent; light mode -> deeper, stronger one.
#
# How: quantize the image to 16 colours, then pick the colour that covers the
# most pixels *among the vivid ones* (night photos are mostly near-black, and
# "the most common colour" would be an unreadable dark grey). Hue is kept;
# saturation/lightness are clamped into a range that reads well on that bar.
# If the photo has no vivid colour at all (e.g. black & white), prints the
# fallback (default: the old purple).

IMG="$1"
MODE="${3:-dark}"
if [ "$MODE" = light ]; then DEF="#8839EF"; LMIN=0.36; LMAX=0.46; SMIN=0.50; SMAX=0.85
else                         DEF="#B57EDC"; LMIN=0.62; LMAX=0.78; SMIN=0.45; SMAX=0.80; fi
FALLBACK="${2:-$DEF}"
[ -f "$IMG" ] || { echo "$FALLBACK"; exit 0; }

magick "$IMG" -resize 200x200 +dither -colors 16 -depth 8 -format %c histogram:info:- 2>/dev/null |
awk -v fb="$FALLBACK" -v lmin=$LMIN -v lmax=$LMAX -v smin=$SMIN -v smax=$SMAX '
function max3(a,b,c){ m=a; if(b>m)m=b; if(c>m)m=c; return m }
function min3(a,b,c){ m=a; if(b<m)m=b; if(c<m)m=c; return m }
function hue2rgb(p,q,t){ if(t<0)t+=1; if(t>1)t-=1
    if(t<1/6) return p+(q-p)*6*t; if(t<1/2) return q
    if(t<2/3) return p+(q-p)*(2/3-t)*6; return p }
{
    # line: "   1234: (r,g,b) #RRGGBB srgb(...)"
    n = $1 + 0
    if (!match($0, /#[0-9A-Fa-f]{6}/)) next
    hex = substr($0, RSTART+1, 6)
    r = strtonum("0x" substr(hex,1,2))/255
    g = strtonum("0x" substr(hex,3,2))/255
    b = strtonum("0x" substr(hex,5,2))/255
    mx = max3(r,g,b); mn = min3(r,g,b); l = (mx+mn)/2; d = mx-mn
    if (d == 0) next                              # pure grey
    s = (l > 0.5) ? d/(2-mx-mn) : d/(mx+mn)
    if (mx == r)      h = (g-b)/d + (g<b ? 6 : 0)
    else if (mx == g) h = (b-r)/d + 2
    else              h = (r-g)/d + 4
    h /= 6
    # ignore near-black, near-white and washed-out colours
    if (l < 0.12 || l > 0.92 || s < 0.18) next
    score = n * (0.4 + s)                         # pixel count, nudged toward vivid
    if (score > best) { best = score; bh = h; bs = s; bl = l }
}
END {
    if (best == 0) { print fb; exit }
    s = bs; if (s < smin) s = smin; if (s > smax) s = smax
    l = bl; if (l < lmin) l = lmin; if (l > lmax) l = lmax
    q = (l < 0.5) ? l*(1+s) : l+s-l*s; p = 2*l-q
    printf "#%02X%02X%02X\n", hue2rgb(p,q,bh+1/3)*255+0.5, hue2rgb(p,q,bh)*255+0.5, hue2rgb(p,q,bh-1/3)*255+0.5
}'
