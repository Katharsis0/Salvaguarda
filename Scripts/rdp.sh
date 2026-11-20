#!/bin/bash
# Remote desktop to the Windows 10 Pro PC over Tailscale (RDP, full GUI).
#   rdp.sh                 connect (asks for user/password only the first time)
#   rdp.sh HOST            another machine
#   rdp.sh --forget [HOST] delete the saved credentials (e.g. after a password change)
#
# Credentials: the user name goes in ~/.config/rdp/<host>.conf; the password
# in the GNOME keyring (encrypted, unlocked when you log in with your password
# at LightDM; after a fingerprint login it asks for the keyring password once).
# It reaches FreeRDP through a file descriptor, so it never shows in `ps`.
# With a Microsoft account: user = account e-mail, password = account password
# (not the PIN). Windows only accepts it over RDP after that password has been
# used once to sign in at the PC itself (PIN/Hello-only accounts are rejected).
#
# Tailscale gives a stable name (MagicDNS) that works at home, at the TEC or on
# mobile data, with no port forwarding; at home it goes direct over the LAN.
# Options: window follows its size (dynamic resolution), RDP graphics pipeline,
# sound + mic, shared clipboard (on by default), ~/Public shared as a drive
# "Linux" in Windows, auto-reconnect, certificate trusted on first use
# (Tailscale already authenticates and encrypts the link).

set -uo pipefail
CONF_DIR="$HOME/.config/rdp"
FORGET=0
[ "${1:-}" = --forget ] && { FORGET=1; shift; }
HOST=${1:-${RDP_HOST:-desktop-qpitifc}}
CONF="$CONF_DIR/$HOST.conf"
mkdir -p "$CONF_DIR"; chmod 700 "$CONF_DIR"

command -v secret-tool >/dev/null || { echo "secret-tool missing (pacman -S libsecret)"; exit 1; }

RDP_USER=""
[ -f "$CONF" ] && . "$CONF"

if [ $FORGET = 1 ]; then
    [ -n "$RDP_USER" ] && secret-tool clear service rdp host "$HOST" user "$RDP_USER" 2>/dev/null
    rm -f "$CONF"; echo "Forgot the credentials for $HOST."; exit 0
fi

if [ -z "$RDP_USER" ]; then
    read -rp "Windows user for $HOST (e-mail for a Microsoft account): " RDP_USER
    [ -n "$RDP_USER" ] || { echo "No user given."; exit 1; }
fi

PASS=$(secret-tool lookup service rdp host "$HOST" user "$RDP_USER" 2>/dev/null)
NEW=0
if [ -z "$PASS" ]; then
    read -rsp "Windows password for $RDP_USER (saved in the keyring): " PASS; echo
    [ -n "$PASS" ] || { echo "No password given."; exit 1; }
    NEW=1
fi

# Microsoft accounts: Windows expects the domain "MicrosoftAccount" with the
# whole e-mail as the user name. Given a bare e-mail, FreeRDP would split it
# into user "name" + domain "outlook.com" and the logon fails.
LOGIN=$RDP_USER
[[ $LOGIN == *@* && $LOGIN != *\\* ]] && LOGIN="MicrosoftAccount\\$LOGIN"

mkdir -p "$HOME/Public"
# One argument per line; /args-from can't be mixed with other arguments.
args() {
    printf '%s\n' "/v:$HOST" "/u:$LOGIN" "/p:$PASS" \
        +dynamic-resolution /size:90% /network:auto /gfx \
        /sound:sys:pulse /microphone:sys:pulse "/drive:Linux,$HOME/Public" \
        /auto-reconnect /auto-reconnect-max-retries:30 /cert:tofu "/t:Windows ($HOST)" \
        '/auth-pkg-list:!kerberos'
    # ^ a personal PC with a Microsoft account authenticates with NTLM. With
    #   Kerberos enabled, FreeRDP takes "name@outlook.com" as a domain login, looks
    #   for an "OUTLOOK.COM" Kerberos server and the logon fails.
}
save_creds() {  # user name file only once the keyring really holds the password
    printf '%s' "$PASS" | secret-tool store --label="RDP $HOST ($RDP_USER)" service rdp host "$HOST" user "$RDP_USER" 2>/dev/null \
        && printf 'RDP_USER=%q\n' "$RDP_USER" > "$CONF"
}
if [ $NEW = 1 ]; then
    save_creds || echo "Couldn't save the password in the keyring (is gnome-keyring installed? run setup_laptop.sh). Connecting anyway."
fi

LOG=$(mktemp); trap 'rm -f "$LOG"' EXIT
xfreerdp3 /args-from:fd:3 3< <(args) 2> >(tee "$LOG" | grep -v -E 'no RDP scancode found|x509_utils_from_pem|tls_print_new_certificate_warn|Certificate verification failure|CN = ' >&2)
rc=$?
sleep 0.2   # let the stderr filter finish writing $LOG

# Windows rejected the credentials: forget them so the next run asks again
if grep -q -E 'LOGON_FAILURE|AUTHENTICATION_FAILED|WRONG_PASSWORD|ACCOUNT_RESTRICTION|PASSWORD_EXPIRED|LOGON_TYPE_NOT_GRANTED' "$LOG"; then
    secret-tool clear service rdp host "$HOST" user "$RDP_USER" 2>/dev/null
    rm -f "$CONF"
    echo "Windows rejected the user or password; forgot them. Run 'windows' again to retype."
elif [ $NEW = 1 ] && [ -f "$CONF" ]; then
    echo "Saved: next time 'windows' connects without asking."
fi
unset PASS
exit $rc
