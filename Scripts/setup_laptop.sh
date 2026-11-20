#!/bin/bash
# One-time system setup for the ThinkPad T480 (run as your user; asks for sudo):
#   1. Battery charge limits: charge both batteries to 80% and only start again
#      below 40% (slows battery wear). `battery_charge.sh full` lifts the limit
#      for one charge (clicking the polybar battery module does that).
#      The limit is stored in the battery firmware, so Windows sees it too.
#   2. TLP power management (CPU/Wi-Fi/USB/disk tuned for AC vs battery).
#      The Bluetooth adapter and the fingerprint reader are kept out of USB
#      autosuspend (the Keychron would lag and python-validity would break).
#   3. throttled: fixes the T480's known CPU throttling bug (BD PROCHOT /
#      power limits reset by the firmware).
#   4. fwupd: firmware updates (BIOS, Thunderbolt NVM, ...). Only checks and
#      lists them; installing is your call: `fwupdmgr update`.
#   5. Weekly maintenance: paccache.timer (keep the last 2 versions of each
#      package, drop uninstalled ones) and reflector.timer (fresh mirrors).
#   6. Packages for the desktop bits: playerctl (media keys), gammastep (night
#      light), udiskie (USB automount), gnome-keyring (saved RDP password,
#      unlocked at login by LightDM's PAM), rclone (cloud uploads for
#      Scripts/backup_secrets.sh).
# Every edited file gets a .bak-laptop backup. Safe to re-run.

set -euo pipefail
[ "$(id -u)" = 0 ] && { echo "Run as your normal user (it uses sudo itself)."; exit 1; }
ME=$(id -un)
bak() { sudo test -e "$1" && ! sudo test -e "$1.bak-laptop" && sudo cp -a "$1" "$1.bak-laptop" || true; }
say() { printf '\n\033[1;35m== %s\033[0m\n' "$*"; }

say "Packages"
sudo pacman -S --needed --noconfirm tlp throttled fwupd pacman-contrib reflector \
    playerctl gammastep udiskie udisks2 rclone gnome-keyring

# ----------------------------------------------------------------- 1+2 TLP
say "TLP + battery charge limits (40-80%)"
sudo install -d /etc/tlp.d
sudo tee /etc/tlp.d/01-dotfiles.conf >/dev/null <<'EOF'
# Managed by ~/GitHub/dotfiles/Scripts/setup_laptop.sh
# Battery care: charge to 80%, start charging again below 40%
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=80
START_CHARGE_THRESH_BAT1=40
STOP_CHARGE_THRESH_BAT1=80
# Keep the Bluetooth adapter (Keychron keyboard) and the fingerprint reader
# (python-validity) out of USB autosuspend
USB_EXCLUDE_BTUSB=1
USB_DENYLIST="06cb:009a"
# Sensible AC/battery split
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
EOF
# TLP handles radio states itself; systemd-rfkill would fight it
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
sudo systemctl enable --now tlp.service
sudo tlp start >/dev/null

# Let the polybar click switch charge modes without a password (these two
# TLP sub-commands only, nothing else)
sudo tee /etc/sudoers.d/50-tlp-charge >/dev/null <<EOF
# Managed by dotfiles setup_laptop.sh: battery_charge.sh full/limit
$ME ALL=(root) NOPASSWD: /usr/bin/tlp fullcharge, /usr/bin/tlp setcharge
EOF
sudo chmod 440 /etc/sudoers.d/50-tlp-charge
sudo visudo -cf /etc/sudoers.d/50-tlp-charge >/dev/null || { sudo rm /etc/sudoers.d/50-tlp-charge; echo "!! sudoers rule invalid, removed"; }

# ----------------------------------------------------------------- 3 throttled
say "throttled (T480 throttling fix)"
sudo systemctl enable --now throttled.service

# ----------------------------------------------------------------- 4 fwupd
say "Firmware updates (fwupd)"
sudo fwupdmgr refresh --force >/dev/null 2>&1 || true
fwupdmgr get-updates 2>/dev/null || echo "   (no updates listed, or the check failed)"
echo "   To install listed updates: fwupdmgr update   (BIOS updates reboot the laptop; keep it plugged in)"

# ----------------------------------------------------------------- 5 maintenance
say "Weekly maintenance timers"
sudo install -d /etc/systemd/system/paccache.service.d
sudo tee /etc/systemd/system/paccache.service.d/dotfiles.conf >/dev/null <<'EOF'
# Managed by dotfiles setup_laptop.sh: keep 2 versions, drop uninstalled packages
[Service]
ExecStart=
ExecStart=/usr/bin/paccache -rk2
ExecStart=/usr/bin/paccache -ruk0
EOF
bak /etc/xdg/reflector/reflector.conf
sudo tee /etc/xdg/reflector/reflector.conf >/dev/null <<'EOF'
# Managed by dotfiles setup_laptop.sh (reflector.timer, weekly)
--save /etc/pacman.d/mirrorlist
--country US,MX
--protocol https
--latest 20
--sort rate
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now paccache.timer reflector.timer

say "Done"
tlp-stat -b 2>/dev/null | grep -E 'charge_control_(start|end)_threshold' | sed 's/^/   /' || true
echo "   Log out and back in (or Super+Shift+R) so i3 starts gammastep and udiskie."
