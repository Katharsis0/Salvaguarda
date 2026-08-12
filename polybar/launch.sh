#!/usr/bin/env sh

pkill -x polybar

# Wait until the old instances are gone
while pgrep -x polybar >/dev/null; do sleep 0.2; done

if type "xrandr" >/dev/null 2>&1; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    case "$m" in
      eDP-1) BAR=main ;;
      *)     BAR=secondary ;;
    esac
    MONITOR=$m polybar --reload "$BAR" >/dev/null 2>&1 &
  done
else
  polybar --reload main >/dev/null 2>&1 &
fi
