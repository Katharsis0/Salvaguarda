#!/bin/bash
# Keybinding cheatsheet: a searchable rofi list built live from i3/config,
# so it never goes stale. Bound to $mod+F1.
#   - description = the comment right above a binding; for a group of
#     bindings under one comment, the command itself is shown (made readable)
#   - type to filter (e.g. "workspace", "shift", "theme")
#   - Enter runs the selected binding
#   keybinds.sh --print   just print the table (e.g. to grep in a terminal)

CONF="$HOME/.config/i3/config"

table() {
python3 - "$CONF" <<'PY'
import re, sys

lines = open(sys.argv[1]).read().splitlines()
vars_ = {}
for l in lines:
    m = re.match(r'\s*set\s+(\$\w+)\s+(.+)', l)
    if m:
        vars_[m.group(1)] = m.group(2).strip().strip('"')

KEYS = {
    'Mod4': 'Super', '$mod': 'Super', 'Mod1': 'Alt', 'Shift': 'Shift', 'shift': 'Shift',
    'Control': 'Ctrl', 'Ctrl': 'Ctrl', 'Return': 'Enter', 'space': 'Space',
    'semicolon': ';', 'greater': '>', 'less': '<', 'Escape': 'Esc',
    'XF86AudioRaiseVolume': 'Volume Up', 'XF86AudioLowerVolume': 'Volume Down',
    'XF86AudioMute': 'Mute', 'XF86AudioMicMute': 'Mic Mute',
    'XF86MonBrightnessUp': 'Brightness Up', 'XF86MonBrightnessDown': 'Brightness Down',
    'Left': '←', 'Right': '→', 'Up': '↑', 'Down': '↓',
}
def keyname(combo):
    parts = [KEYS.get(p, p.upper() if len(p) == 1 else p) for p in combo.split('+')]
    return ' + '.join(parts)

def subst(s):
    for k in sorted(vars_, key=len, reverse=True):
        s = s.replace(k, vars_[k])
    return s

def human(cmd):
    c = subst(cmd)
    c = re.sub(r'\s*&&\s*\$refresh_i3status', '', cmd)
    c = subst(c)
    c = re.sub(r'^exec\s+(--no-startup-id\s+)?', '', c).strip('"\' ')
    c = re.sub(r'~?/[\w./~-]*/([\w.-]+)', r'\1', c)          # paths -> basename
    c = re.sub(r'^i3-nagbar .*i3-msg exit.*', 'exit i3 (log out)', c)
    c = c.replace('workspace number ', 'workspace ')
    c = c.replace('move container to workspace', 'move window to workspace')
    c = re.sub(r'pactl set-sink-volume \S+ ([+-]\d+%)', r'volume \1', c)
    c = re.sub(r'pactl set-sink-mute \S+ toggle', 'mute speakers', c)
    c = re.sub(r'pactl set-source-mute \S+ toggle', 'mute microphone', c)
    c = re.sub(r'brightnessctl set (\S+)', r'brightness \1', c)
    c = re.sub(r'^mode "default"?$', 'leave this mode', c)
    c = re.sub(r'^mode "(\w+)"?$', lambda m: f'{m.group(1)} mode (J/K/L/; or arrows, Esc to leave)', c)
    return FRIENDLY.get(c, c)

FRIENDLY = {
    'powermenu_t2': 'Power menu (lock / sleep / reboot / shut down)',
    'lock_screen': 'Lock screen (touch sensor or type password)',
    'flameshot gui': 'Screenshot',
}

def clean_comment(c):
    c = c.lstrip('#').strip()
    return c[0].upper() + c[1:] if c else c

rows = []          # (section, keys, description, command)
mode = None
i = 0
while i < len(lines):
    l = lines[i].strip()
    m = re.match(r'mode\s+"([^"]+)"\s*\{', l)
    if m:
        mode = m.group(1); i += 1; continue
    if l == '}':
        mode = None; i += 1; continue
    if l.startswith('bindsym') or l.startswith('bindcode'):
        # gather this block of consecutive bindings
        block = []
        j = i
        while j < len(lines) and re.match(r'\s*bind(sym|code)\s', lines[j]):
            block.append(lines[j].strip()); j += 1
        # the comment directly above the block (skip blank-free comment run)
        k = i - 1; comment = ''
        while k >= 0 and lines[k].strip().startswith('#'):
            t = lines[k].strip()
            if re.match(r'#+\s*(same|alternatively)', t, re.I):
                break                                   # "same as above" notes
            if not re.match(r'#+\s*(bindsym|bindcode|exec|set )', t):
                comment = t
                break
            k -= 1
        for b in block:
            parts = b.split(None, 2)
            if len(parts) < 3: continue
            _, combo, cmd = parts
            while combo.startswith('--'):            # --release etc.
                combo, cmd = cmd.split(None, 1)[0], cmd.split(None, 1)[1]
            desc = clean_comment(comment) if (len(block) == 1 and comment) else human(cmd)
            sec = f'[{mode}] ' if mode else ''
            rows.append((sec + keyname(combo), desc, cmd))
        i = j; continue
    i += 1

# things that aren't i3 bindings
extras = [
    ('Super + L', 'Lock screen (touch sensor or type password)', None),
    ('AltGr + H / J / K / L', 'Arrow keys ← ↓ ↑ →', None),
    ('Shift + Enter (Alacritty)', 'Newline without running the command', None),
    ('title <name> (shell)', 'Rename this terminal window', None),
]
seen = {r[0] for r in rows}
rows += [e for e in extras if e[0] not in seen]

w = max(len(r[0]) for r in rows) + 3
for keys, desc, cmd in rows:
    print(f'{keys:<{w}}{desc}\t{cmd or ""}')
PY
}

if [ "${1:-}" = "--print" ]; then
    table | cut -f1
    exit 0
fi

TABLE=$(table)
SEL=$(cut -f1 <<<"$TABLE" | rofi -dmenu -i -p "󰌌 Keybinds" -no-custom \
      -format i -l 18 \
      -theme-str 'window {width: 860px;} element-text {font: "JetBrainsMono Nerd Font 11";}') || exit 0
CMD=$(sed -n "$((SEL + 1))p" <<<"$TABLE" | cut -f2)
[ -n "$CMD" ] && i3-msg -q "$CMD"
exit 0
