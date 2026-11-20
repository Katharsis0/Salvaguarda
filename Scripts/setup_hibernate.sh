#!/bin/bash
# One-time system setup (run with sudo):
#   1. Hibernation: a 16G /swapfile (zram stays the normal swap; the file is
#      only for the hibernation image), `resume` initramfs hook, resume= and
#      resume_offset= kernel params in GRUB.
#   2. Power policy: lid close -> suspend-then-hibernate (if the battery runs
#      low while suspended it hibernates instead of dying); UPower's last-resort
#      critical action -> Hibernate. The 2-minute countdown is battery_guard.
#   3. Fingerprint at the LightDM login screen (+ start the sensor service
#      before LightDM so it's ready at boot).
#   4. Login screen background: desktop_bgs/welcome.jpg ("Hello friend").
# Every edited file gets a .bak-hibernate backup. Safe to re-run.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }

SWAP=/swapfile
SWAP_SIZE=16G
bak() { [ -e "$1.bak-hibernate" ] || cp -a "$1" "$1.bak-hibernate"; }

ROOT_DEV=$(findmnt -no SOURCE /)
ROOT_UUID=$(findmnt -no UUID /)
[ "$(findmnt -no FSTYPE /)" = ext4 ] || { echo "root is not ext4, aborting"; exit 1; }

# ---------------------------------------------------------------- 1. swapfile
if [ ! -f "$SWAP" ]; then
    echo "==> Creating $SWAP_SIZE $SWAP"
    mkswap -U clear --size "$SWAP_SIZE" --file "$SWAP"
fi
if ! grep -q "^$SWAP " /etc/fstab; then
    bak /etc/fstab
    # low priority: zram (pri 100) keeps being used first for normal swapping
    echo "$SWAP none swap defaults,pri=-2 0 0" >> /etc/fstab
fi
swapon --show=NAME --noheadings | grep -qx "$SWAP" || swapon -p -2 "$SWAP"

OFFSET=$(filefrag -v "$SWAP" | awk '$1=="0:" {sub(/\.\.$/,"",$4); print $4}')
[ -n "$OFFSET" ] || { echo "could not compute resume_offset"; exit 1; }
echo "    resume=UUID=$ROOT_UUID resume_offset=$OFFSET ($ROOT_DEV)"

# ---------------------------------------------------------------- initramfs
if ! grep -qE '^HOOKS=.*\bresume\b' /etc/mkinitcpio.conf; then
    echo "==> Adding resume hook to mkinitcpio"
    bak /etc/mkinitcpio.conf
    sed -i -E '/^HOOKS=/ s/\bfilesystems\b/filesystems resume/' /etc/mkinitcpio.conf
    grep -E '^HOOKS=' /etc/mkinitcpio.conf
    mkinitcpio -P
fi

# ---------------------------------------------------------------- GRUB
echo "==> Adding resume params to GRUB"
bak /etc/default/grub
sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ {
    s/ ?resume(_offset)?=[^" ]*//g
    s/"$/ resume=UUID='"$ROOT_UUID"' resume_offset='"$OFFSET"'"/
}' /etc/default/grub
grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# ---------------------------------------------------------------- 2. power policy
echo "==> logind: lid close -> suspend-then-hibernate on battery"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/10-hibernate.conf <<'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
HandleSuspendKey=suspend-then-hibernate
EOF
# No HibernateDelaySec: systemd then hibernates a suspended laptop only when
# the battery is about to run out (it wakes up periodically to check).

echo "==> UPower: last-resort critical action -> Hibernate"
bak /etc/UPower/UPower.conf
sed -i -E 's/^CriticalPowerAction=.*/CriticalPowerAction=Hibernate/' /etc/UPower/UPower.conf

# ---------------------------------------------------------------- 3. LightDM fingerprint
echo "==> Fingerprint at the LightDM login screen"
if ! grep -q pam_fprintd /etc/pam.d/lightdm; then
    bak /etc/pam.d/lightdm
    # Password first (typed password logs in as usual). Press Enter on an
    # empty field -> "place your finger" -> touch the sensor.
    sed -i '0,/^auth/s//auth        sufficient  pam_unix.so nodelay\nauth        sufficient  pam_fprintd.so max-tries=3 timeout=20\n&/' /etc/pam.d/lightdm
fi
cat /etc/pam.d/lightdm | grep -E '^-?auth'

mkdir -p /etc/systemd/system/lightdm.service.d
cat > /etc/systemd/system/lightdm.service.d/fingerprint.conf <<'EOF'
[Unit]
Wants=python3-validity.service open-fprintd.service
After=python3-validity.service open-fprintd.service
EOF
systemctl daemon-reload

# ---------------------------------------------------------------- 4. welcome screen
WELCOME="$(dirname "$(readlink -f "$0")")/../desktop_bgs/welcome.jpg"
if [ -f "$WELCOME" ]; then
    echo "==> Login screen background: welcome.jpg"
    # the greeter runs as the lightdm user, which can't read /home
    install -Dm644 "$WELCOME" /usr/share/backgrounds/welcome.jpg
    [ -f /etc/lightdm/slick-greeter.conf ] && bak /etc/lightdm/slick-greeter.conf
    cat > /etc/lightdm/slick-greeter.conf <<'EOF2'
[Greeter]
background=/usr/share/backgrounds/welcome.jpg
background-color=#000000
draw-user-backgrounds=false
draw-grid=false
EOF2
fi

echo
echo "Done. Reboot, then test hibernation with:  systemctl hibernate"
echo "(Logind config takes effect after reboot.)"
