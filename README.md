# Salvaguarda
```
```
save
```
```
activate
```


# Timezone
```
timedatectl set-timezone America/Costa_Rica
```

# Keyboard lang=latam
```
setxkbmap -layout latam
```

# Input management
Para establecer la distribución del teclado, el idioma y el modelo se debe modificar el archivo de 00-keyboard.conf en el directorio de X11 en ```/etc/X11/xorg.conf.d``. Si no existe, crearlo con la siguiente config:

```
#~/etc/X11/xorg.conf.d/00-keyboard.conf
# Written by systemd-localed(8), read by systemd-localed and Xorg. It's
# probably wise not to edit this file manually. Use localectl(1) to
# update this file.
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "latam"
        Option "XkbModel" "pc105+inet"
EndSection

```

Para estalecer el sentido del scroll, el tap, double tap y otros gestos en el mousepad:
```
#~/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
    Identifier "devname"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "ClickMethod" "clickfinger"
    Option "NaturalScrolling" "true"

EndSection
```


