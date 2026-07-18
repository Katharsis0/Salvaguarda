#!/usr/bin/env bash
# Bound to Super+V in i3. Ensures the copyq server survives an accidental
# Ctrl+Q (which quits the whole server, not just the window) and shows the
# lightweight popup menu instead of the full editor window.

pgrep -x copyq >/dev/null || {
    copyq --start-server &
    disown
    sleep 0.5
}

copyq menu
