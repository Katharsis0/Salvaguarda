# Salvaguarda
Instrucciones del Sebas del pasado para el Sebas del futuro en caso de que requiera de reinstalar Arch y reestablecer la configuración customizada.

-Nota: Priorizar el backupeo de los archivos del sistema en un disco externo para redundar la informacion en caso de situaciones críticas

# Arch
Para instalar se debe flashear un USB drive con la imagen. Una vez flasheada, se conecta a la compu y se bootea.

Una vez instalado el kernel, es posible correr el comando:

```
archinstall
```
Lo cual corre el script de instalación. Ahi se puede seleccionar todo lo importante según sea necesario. 

# NetworkManager, Wifi y conexión a WPA2-Enterprise
Asumiendo que la instalación inicial se realizó con conexión ethernet, a continuación se describe lo necesario para poder conectarse al WiFi.

- Se debe instalar NetworkManager
  ```
  sudo pacman -S networkmanager
  ```
  
  ```
  paru -S networkmanager
  ```
- Luego se debe start y enable el servicio
  ```
  systemctl enable NetworkManager.service
  ```
  ```
  systemctl start NetworkManager.service
  ```
- Una vez inicializado el servicio, procedemos a acceder al       wifi con
  ```
  nmtui
  ```
Para conectarse a una red WPA2-Enterprise como wTEC:
```
nmcli con add type wifi ifname wlan0 con-name wTEC ssid wTEC
```
```
nmcli con edit id wTEC
```

```
set ipv4.method auto
```
```
set 802-1x.eap peap
```
```
set 802-1x.phase2-auth mschapv2
```
```
set 802-1x.identity hvsebas@estudiantes.tec.cr
```
```
set 802-1x.password PASSWORD
```
```
set wifi-sec.key-mgmt wpa-eap
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

# Clipboard manager (CopyQ)
Historial de portapapeles al estilo Win+V / XFCE clipman, con soporte para texto e imágenes. Se abre con `Super+V`.

```
sudo pacman -S copyq
```
Simlinkear `copyq/` (ver `symlinks.txt`) y correr una vez:
```
~/.config/copyq/setup.sh
```




# Tema claro/oscuro y fondos de pantalla
Un solo interruptor (`Super+T`, o `Scripts/theme.sh dark|light|toggle`) cambia polybar, Alacritty, los bordes/barras de título de i3, el lock screen y el fondo. El modo actual se guarda en `~/.cache/theme_mode`.

Dependencias: `imagemagick`, `jq`, `curl`, `feh`, `dunst` (`libnotify`), `i3lock-color`.

**Fondos rotativos** (`Scripts/photo_wallpaper.sh`, arrancado por i3 con `--daemon`): cada modo tiene su propia foto y cambia cada 3 días.
- Oscuro: bosques (Wikimedia Commons, *Quality images of forests*). Las fotos muy claras se saltan y las demás se oscurecen para que sirvan de noche.
- Claro: animales (Wikimedia Commons, *Featured pictures of animals*), tal cual.
- `Super+O` → botón 󰸉 = foto nueva ya (el logout quedó en `Super+Shift+E`).
- `photo_wallpaper.sh --info` muestra autor y licencia (casi todas CC BY-SA: hay que dar crédito al autor), `--revert` vuelve a la foto anterior.
- Sin API key (Unsplash no permite apps de fondos de pantalla en su API). Sin internet se queda la foto actual; si no hay ninguna se usan `desktop_bgs/death_bg.png` / `light_bg.jpg`.
- Las fotos viven en `~/.cache/wallpapers/<modo>/`, nunca en el repo (es público).

**Color de acento**: `Scripts/accent_color.sh` reduce la foto a 16 colores, descarta casi-negros, casi-blancos y grises, y elige el que más cubre (con un pequeño bonus a los más vivos). Se conserva el tono y se ajusta claridad/saturación para que se lea en la barra: más suave en oscuro, más profundo en claro. Ese acento va a polybar (`primary`), a las barras de título y bordes de i3, al cursor/selección de Alacritty y al lock screen.

**Paleta clara "bone"** (`#F2EEE6`): blanco hueso en vez de blanco puro, menos agresivo pero con buen contraste para días soleados. Alacritty claro usa `alacritty/bone-light.toml` (Catppuccin Latte sobre fondo hueso).

Archivos generados por `theme.sh` (no se versionan): `polybar/colors-current.ini`, `alacritty/theme-current.toml`, `i3/theme-current.conf` (incluido desde `i3/config`).
