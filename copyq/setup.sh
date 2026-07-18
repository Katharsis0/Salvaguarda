#!/usr/bin/env bash
# One-time CopyQ setup. Run this once after installing copyq and symlinking
# this repo's copyq/ into ~/.config/copyq (see symlinks.txt).
#
# Safe to re-run: `copyq config` just overwrites the same keys. If a key name
# doesn't exist in your installed version, copyq prints a warning for that
# line and moves on — it won't corrupt anything else.

set -e

if ! command -v copyq >/dev/null; then
    echo "copyq is not installed. Install it first: sudo pacman -S copyq"
    exit 1
fi

# Make sure the server is running before we try to configure it.
copyq --start-server >/dev/null 2>&1 &
sleep 1

# --- Clipboard capture ---
copyq config check_clipboard true      # watch Ctrl+C / Ctrl+V clipboard
copyq config check_selection true      # also capture X11 PRIMARY (mouse-drag select in terminals, etc.)
copyq config copy_clipboard true
copyq config copy_selection false      # don't let a mouse selection silently overwrite the real clipboard
copyq config maxitems 200

# --- Flyout / Win+V-style behavior ---
copyq config activate_pastes true      # Enter on an item pastes straight into the window you came from
copyq config activate_closes true      # picking an item closes the popup
copyq config always_on_top true
copyq config confirm_exit false
copyq config clipboard_notification_lines 0  # dunst already handles notifications; don't double up

# --- Keep the (rarely used) main/editor window lean, in case you open it with `copyq show` ---
copyq config hide_toolbar true
copyq config hide_tabs true
copyq config hide_toolbar_help true

echo "CopyQ configured. Super+V opens the clipboard history popup (menu)."
echo
echo "One more manual step (GUI, one-time): CopyQ's default Ctrl+Q shortcut"
echo "quits the whole server, not just the window, so it can't be brought back"
echo "until you relaunch it by hand. To stop that from happening by accident:"
echo "  1. Run: copyq show"
echo "  2. Open Preferences (tray icon right-click, or Ctrl+P) -> Shortcuts tab"
echo "  3. Find the 'Exit' action, click its shortcut field, press Backspace"
echo "     to clear Ctrl+Q (or set it to something obscure like Ctrl+Alt+Shift+Q)"
echo "  4. Save"
