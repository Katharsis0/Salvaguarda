#!/bin/bash
# Encrypted backup of the secrets the public dotfiles repo can't hold, so a
# lost laptop can be fully rebuilt (install.sh + this).
#
#   backup_secrets.sh              make a backup (asks for a passphrase), upload it
#   backup_secrets.sh restore FILE decrypt FILE and put everything back
#   backup_secrets.sh list         show the local backups
#
# Contents: ~/.ssh, ~/.gnupg (no sockets/locks), ~/.android (adb key),
# ~/.config/openweather, ~/.config/unsplash, and the saved Wi-Fi networks
# (/etc/NetworkManager/system-connections, via sudo).
# Encryption: gpg symmetric AES-256 with your passphrase (gpg ships with every
# Arch install, so restoring needs nothing extra). Keep the passphrase
# somewhere safe outside this laptop: without it the backup is useless, by design.
#
# Destination (~/.config/backup_secrets.conf, outside the repo):
#   DEST=local                       only ~/Backups/secrets (default)
#   DEST=rclone:<remote>:<folder>    any cloud set up with `rclone config`
#                                    (Google Drive, Dropbox, OneDrive, MEGA...)
#                                    e.g. DEST=rclone:gdrive:Backups/secrets
# A copy always stays in ~/Backups/secrets (last 5 kept).

set -uo pipefail
OUTDIR="$HOME/Backups/secrets"
CONF="$HOME/.config/backup_secrets.conf"
KEEP=5
DEST=local
[ -f "$CONF" ] && . "$CONF"
mkdir -p "$OUTDIR"; chmod 700 "$OUTDIR"

die()  { echo "backup_secrets: $*" >&2; exit 1; }
ask_pass() {  # $1 = confirm? -> PASS
    read -rsp "Passphrase: " PASS; echo
    [ -n "$PASS" ] || die "empty passphrase"
    if [ "${1:-}" = confirm ]; then
        read -rsp "Repeat it:  " P2; echo
        [ "$PASS" = "$P2" ] || die "passphrases don't match"
    fi
}

upload_rclone() {
    command -v rclone >/dev/null || die "rclone not installed (sudo pacman -S rclone)"
    rclone copy "$1" "${DEST#rclone:}" || die "rclone upload failed (check: rclone config)"
    echo "Uploaded to ${DEST#rclone:}"
}

backup() {
    local stamp tmp out
    stamp=$(date +%Y%m%d-%H%M)
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    out="$OUTDIR/secrets-$stamp.tar.gpg"

    # home parts
    local items=() p
    for p in .ssh .gnupg .android .config/openweather .config/unsplash; do
        [ -e "$HOME/$p" ] && items+=("$p")
    done
    tar -C "$HOME" --exclude='.gnupg/S.*' --exclude='*.lock' --exclude='.gnupg/random_seed' \
        -cf "$tmp/home.tar" "${items[@]}" || die "couldn't read the home files"

    # Wi-Fi networks (root-only files)
    echo "Saved Wi-Fi networks need sudo:"
    if sudo tar -C / -cf "$tmp/nm.tar" etc/NetworkManager/system-connections; then
        sudo chown "$(id -u):$(id -g)" "$tmp/nm.tar"
    else
        echo "   (skipped the Wi-Fi networks)"
    fi
    { echo "made: $(date -Iseconds)"; echo "host: $(cat /etc/hostname)"; echo "home: ${items[*]}"
      [ -f "$tmp/nm.tar" ] && echo "wifi: $(tar -tf "$tmp/nm.tar" | grep -c '\.nmconnection$') networks"; } > "$tmp/MANIFEST"

    ask_pass confirm
    tar -C "$tmp" -cf - MANIFEST home.tar $( [ -f "$tmp/nm.tar" ] && echo nm.tar ) |
        gpg --batch --yes --pinentry-mode loopback --passphrase-fd 3 \
            --symmetric --cipher-algo AES256 -o "$out" 3<<<"$PASS" || die "encryption failed"
    unset PASS
    chmod 600 "$out"
    echo "Backup: $out ($(du -h "$out" | cut -f1))"; cat "$tmp/MANIFEST" | sed 's/^/   /'

    case "$DEST" in
        local)     echo "Only stored locally. Set DEST in $CONF to upload it (see the top of this script)." ;;
        rclone:*)  upload_rclone "$out" ;;
        *)         echo "Unknown DEST=$DEST in $CONF; kept locally." ;;
    esac
    # keep the newest $KEEP local copies
    ls -1t "$OUTDIR"/secrets-*.tar.gpg 2>/dev/null | tail -n +$(( KEEP + 1 )) | xargs -r rm -f
    date +%s > "$OUTDIR/.last_backup"
}

restore() {
    local f=${1:-}; [ -f "$f" ] || die "usage: backup_secrets.sh restore FILE"
    local tmp; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    ask_pass
    gpg --batch --pinentry-mode loopback --passphrase-fd 3 -d "$f" 3<<<"$PASS" 2>/dev/null | tar -C "$tmp" -xf - \
        || die "wrong passphrase or damaged file"
    unset PASS
    cat "$tmp/MANIFEST"; echo
    read -rp "Restore these into your home (existing files are overwritten)? [y/N] " r
    [[ $r == [yYsS]* ]] || exit 0
    tar -C "$HOME" -xf "$tmp/home.tar"
    chmod 700 "$HOME/.ssh" "$HOME/.gnupg" 2>/dev/null; chmod 600 "$HOME"/.ssh/id_* 2>/dev/null; chmod 644 "$HOME"/.ssh/*.pub 2>/dev/null
    if [ -f "$tmp/nm.tar" ]; then
        read -rp "Also restore the saved Wi-Fi networks (sudo)? [y/N] " r
        if [[ $r == [yYsS]* ]]; then
            sudo tar -C / -xf "$tmp/nm.tar" && sudo chmod 600 /etc/NetworkManager/system-connections/* \
                && sudo nmcli connection reload && echo "Wi-Fi networks restored."
        fi
    fi
    echo "Done."
}

case "${1:-backup}" in
    backup)  backup ;;
    restore) restore "${2:-}" ;;
    list)    ls -lh "$OUTDIR"/secrets-*.tar.gpg 2>/dev/null || echo "no backups yet" ;;
    *)       sed -n '2,25p' "$0" ;;
esac
