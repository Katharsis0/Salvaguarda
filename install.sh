#!/usr/bin/env bash
# Rebuild this setup on a fresh Arch install (after archinstall + network).
#
#   git clone git@github.com:Katharsis0/Salvaguarda.git ~/GitHub/dotfiles
#   ~/GitHub/dotfiles/install.sh --dry-run     # show what would happen
#   ~/GitHub/dotfiles/install.sh               # do it, asking before each step
#   ~/GitHub/dotfiles/install.sh --yes         # do it without asking
#
# Steps: packages (pacman + AUR via paru + VS Code extensions), symlinks from
# symlinks.txt, home files and /etc files from system/, services, and the
# one-time hardware scripts (fingerprint, hibernation). Anything already in the
# way is moved to <name>.bak-<date>, never deleted. Safe to re-run.
# Secrets are NOT in the repo; see "Pasos manuales" in README.md.

set -uo pipefail
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
SYS="$DOTFILES/system"
STAMP=$(date +%Y%m%d-%H%M%S)
DRY=0; YES=0
for a in "$@"; do case $a in
    --dry-run|-n) DRY=1 ;;
    --yes|-y)     YES=1 ;;
    -h|--help)    sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $a"; exit 1 ;;
esac; done

say()  { printf '\n\033[1;35m== %s\033[0m\n' "$*"; }
run()  { if [ $DRY = 1 ]; then printf '   would run: %s\n' "$*"; else "$@"; fi; }
ask()  { [ $DRY = 1 ] || [ $YES = 1 ] && return 0; read -rp "$1 [y/N] " r; [[ $r == [yYsS]* ]]; }
# Move whatever is at $1 out of the way (unless it's already the right symlink)
backup() { if [ -e "$1" ] || [ -L "$1" ]; then run mv "$1" "$1.bak-$STAMP"; fi; }

# ------------------------------------------------------------------ packages
step_packages() {
    say "Packages"
    ask "Install $(wc -l < "$SYS/packages/pacman.txt") repo packages + $(wc -l < "$SYS/packages/aur.txt") AUR packages?" || return
    # only names that still exist in the repos (renamed/dropped ones are listed)
    local avail; avail=$(pacman -Slq | sort -u)
    local missing; missing=$(comm -23 "$SYS/packages/pacman.txt" <(echo "$avail"))
    [ -n "$missing" ] && echo "   not in the repos anymore (check by hand): $(echo $missing)"
    comm -12 "$SYS/packages/pacman.txt" <(echo "$avail") > /tmp/pkgs.$$
    run sudo pacman -S --needed --noconfirm - < /tmp/pkgs.$$; rm -f /tmp/pkgs.$$

    if ! command -v paru >/dev/null; then
        echo "   bootstrapping paru (AUR helper)"
        run sudo pacman -S --needed --noconfirm base-devel git
        local d; d=$(mktemp -d)
        run git clone https://aur.archlinux.org/paru-git.git "$d/paru-git"
        if [ $DRY = 0 ]; then (cd "$d/paru-git" && makepkg -si --noconfirm); fi
    fi
    run paru -S --needed --noconfirm $(grep -v '^paru' "$SYS/packages/aur.txt")

    if command -v code >/dev/null && [ -s "$SYS/packages/vscode-extensions.txt" ]; then
        while read -r e; do run code --install-extension "$e"; done < "$SYS/packages/vscode-extensions.txt"
    fi
}

# ------------------------------------------------------------------ symlinks
step_symlinks() {
    say "Symlinks (from symlinks.txt)"
    ask "Create the dotfile symlinks?" || return
    local src dst
    while read -r _ _ src dst; do
        src=${src/#\~/$HOME}; dst=${dst/#\~/$HOME}
        src=${src%/}
        [[ $dst == */ ]] && dst="$dst$(basename "$src")"
        if [ "$(readlink "$dst")" = "$src" ] || [ "$(readlink "$dst")" = "$src/" ]; then
            echo "   ok    $dst"; continue
        fi
        run mkdir -p "$(dirname "$dst")"
        backup "$dst"
        run ln -s "$src" "$dst"; echo "   link  $dst -> $src"
    done < <(grep -E '^ln -s ' "$DOTFILES/symlinks.txt")
}

# ------------------------------------------------------------------ copied files
step_files() {
    say "Home files (copied: apps rewrite them) and /etc files"
    ask "Copy system/home/* to ~ and system/etc/* to /etc?" || return
    local f rel
    while IFS= read -r f; do
        rel=${f#"$SYS/home/"}
        cmp -s "$f" "$HOME/$rel" && { echo "   ok    ~/$rel"; continue; }
        run mkdir -p "$(dirname "$HOME/$rel")"; backup "$HOME/$rel"
        run cp "$f" "$HOME/$rel"; echo "   copy  ~/$rel"
    done < <(find "$SYS/home" -type f)
    while IFS= read -r f; do
        rel=${f#"$SYS/etc/"}
        cmp -s "$f" "/etc/$rel" && { echo "   ok    /etc/$rel"; continue; }
        [ -e "/etc/$rel" ] && run sudo cp -a "/etc/$rel" "/etc/$rel.bak-$STAMP"
        run sudo install -D -m 644 "$f" "/etc/$rel"; echo "   copy  /etc/$rel"
    done < <(find "$SYS/etc" -type f)
}

# ------------------------------------------------------------------ services
step_services() {
    say "Services"
    local core=(NetworkManager.service bluetooth.service lightdm.service avahi-daemon.service tailscaled.service fstrim.timer systemd-timesyncd.service)
    echo "   core: ${core[*]}"
    echo "   (postgresql and slapd were enabled too: enable them by hand once their data is restored)"
    ask "Enable the core services?" || return
    run sudo systemctl enable "${core[@]}"
}

# ------------------------------------------------------------------ hardware
step_hardware() {
    say "ThinkPad T480 one-time setup"
    echo "   setup_fingerprint.sh : python-validity + open-fprintd, fingerprint for sudo and the lock screen"
    echo "   setup_hibernate.sh   : swapfile + resume, lid -> suspend-then-hibernate, LightDM fingerprint, login background"
    if ask "Run setup_fingerprint.sh?"; then run "$DOTFILES/Scripts/setup_fingerprint.sh"; fi
    if ask "Run setup_hibernate.sh (sudo)?"; then run sudo "$DOTFILES/Scripts/setup_hibernate.sh"; fi
    echo "   setup_laptop.sh      : battery care limit + TLP, throttling fix, firmware check, weekly cleanup, desktop packages"
    if ask "Run setup_laptop.sh?"; then run "$DOTFILES/Scripts/setup_laptop.sh"; fi
    echo "   Secrets (SSH/GPG keys, Wi-Fi): Scripts/backup_secrets.sh restore <file>  (download it from your cloud with rclone)"
}

[ $DRY = 1 ] && echo "DRY RUN: nothing will be changed."
step_packages; step_symlinks; step_files; step_services; step_hardware
say "Done"
echo "   Next: the manual steps in README.md (Pasos manuales), then log out and pick i3 in LightDM."
