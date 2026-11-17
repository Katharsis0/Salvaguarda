#!/bin/bash
# One-time setup: themed locker + fingerprint auth on the ThinkPad T480.
# Sensor 06cb:009a (Synaptics "Metallica") is NOT supported by stock libfprint,
# so this uses python-validity + open-fprintd instead of fprintd.
# Run as your normal user (AUR builds refuse root); it calls sudo itself.
set -euo pipefail

echo "==> Installing i3lock-color (replaces i3lock) and python-validity"
paru -S --needed i3lock-color python-validity

echo "==> Enabling fingerprint services"
sudo systemctl enable --now python3-validity.service open-fprintd.service
# re-init the sensor after suspend
sudo systemctl enable open-fprintd-resume.service open-fprintd-suspend.service python3-validity-suspend-hotfix.service 2>/dev/null || true

PAM_MOD=$(ls /usr/lib/security/pam_fprintd.so 2>/dev/null || true)
if [ -z "$PAM_MOD" ]; then
    echo "!! pam_fprintd.so not found, so PAM files were left alone." >&2
    exit 1
fi

add_fprint() {  # prepend "auth sufficient pam_fprintd.so" once, with a backup
    local f="$1"
    if sudo grep -q pam_fprintd "$f"; then
        echo "    $f already has pam_fprintd"
        return
    fi
    sudo cp "$f" "$f.bak-prefprint"
    sudo sed -i '0,/^auth/s//auth\t\tsufficient\tpam_fprintd.so\n&/' "$f"
    echo "    patched $f (backup: $f.bak-prefprint)"
}

echo "==> Waiting for the sensor driver to register"
for _ in $(seq 20); do
    fprintd-list "$USER" 2>/dev/null | grep -q "Found [1-9]" && break
    sleep 1
done

echo "==> Enrolling your right index finger (touch the sensor repeatedly)"
fprintd-enroll -f right-index-finger "$USER"
fprintd-verify "$USER"

echo "==> Adding fingerprint to sudo and the lock screen"
add_fprint /etc/pam.d/sudo
add_fprint /etc/pam.d/i3lock

echo "Done. Test with:  sudo -k && sudo true"
