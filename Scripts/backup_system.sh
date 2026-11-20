#!/usr/bin/env bash
# Snapshot the parts of the system that live outside the dotfiles symlinks,
# so a fresh Arch install can be rebuilt with ./install.sh.
#   system/packages/pacman.txt          explicitly installed repo packages
#   system/packages/aur.txt             AUR / foreign packages
#   system/packages/vscode-extensions.txt
#   system/etc/...                      hand-made /etc files (see ETC_FILES)
#   system/home/...                     home files that apps rewrite (copied, not symlinked)
# Never copies secrets: no NetworkManager connections, ssh/gpg keys, API keys,
# tailscale state or database contents (the repo is public).
# Run it whenever you install something or change one of these files, then commit.

set -euo pipefail
DOTFILES="$HOME/GitHub/dotfiles"
OUT="$DOTFILES/system"

# /etc files that no setup script recreates. (PAM, logind, GRUB, initramfs,
# swapfile and the LightDM drop-in are rebuilt by setup_fingerprint.sh and
# setup_hibernate.sh, because they depend on the machine.)
ETC_FILES=(
    /etc/X11/xorg.conf.d/00-keyboard.conf
    /etc/X11/xorg.conf.d/30-touchpad.conf
)
# Home files that applications rewrite in place (a symlink would get replaced)
HOME_FILES=(
    .config/mimeapps.list
    .config/autostart/ferdium.desktop
)

mkdir -p "$OUT/packages"
pacman -Qqen | sort > "$OUT/packages/pacman.txt"
pacman -Qqem | grep -v -- '-debug$' | sort > "$OUT/packages/aur.txt"
if command -v code >/dev/null; then code --list-extensions | sort > "$OUT/packages/vscode-extensions.txt"; fi

for f in "${ETC_FILES[@]}"; do
    [ -r "$f" ] || { echo "skip (missing): $f"; continue; }
    install -D -m 644 "$f" "$OUT/etc/${f#/etc/}"
done
for f in "${HOME_FILES[@]}"; do
    [ -r "$HOME/$f" ] || { echo "skip (missing): ~/$f"; continue; }
    install -D -m 644 "$HOME/$f" "$OUT/home/$f"
done

echo "pacman: $(wc -l < "$OUT/packages/pacman.txt")  aur: $(wc -l < "$OUT/packages/aur.txt")  -> $OUT"
git -C "$DOTFILES" status --short -- system
