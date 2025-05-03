#   python ~/.config/i3/configKeys.py
#   reads /i3/config and reports 'bindsym' if they have a preceeding description indicated by '##'

import os
def showKeys():
    keyHelp = ''
    linePrev =  ''
    with open(os.path.expanduser(r"/home/katharsis/.config/i3/config"), 'r') as fp:      # full path to the i3/config
        for line in fp:
            if 'bindsym' in line and len(linePrev)> 2 and linePrev[0:2] == '##':
                key = line.split()[1]                 # grab the keybinding
                desc= linePrev[2:].strip().title()    # grab its description
                if len(keyHelp) > 0:
                    keyHelp += "\n"
                keyHelp += "{:<17} {}".format(key, desc)
            linePrev= line
    return keyHelp

print(showKeys())
