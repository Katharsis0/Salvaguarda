# Salvaguarda
Instrucciones del Sebas del pasado para el Sebas del futuro en caso de que requiera de reinstalar Arch y reestablecer la configuración customizada.

-Nota: Priorizar el backupeo de los archivos del sistema en un disco externo para redundar la informacion en caso de situaciones críticas

# Recuperación rápida
Después de `archinstall` (perfil mínimo + red), con el repo clonado en `~/GitHub/dotfiles`:

```
git clone git@github.com:Katharsis0/Salvaguarda.git ~/GitHub/dotfiles
~/GitHub/dotfiles/install.sh --dry-run   # muestra qué haría, sin tocar nada
~/GitHub/dotfiles/install.sh             # lo hace, preguntando antes de cada paso
```

`install.sh` instala los paquetes (`system/packages/`: pacman, AUR con paru y extensiones de VS Code), crea los symlinks de `symlinks.txt`, copia los archivos de `system/home/` y `system/etc/`, habilita los servicios y ofrece correr `setup_fingerprint.sh` y `setup_hibernate.sh`. Lo que ya exista se mueve a `*.bak-<fecha>`, nunca se borra. Se puede correr varias veces.

Para mantener el respaldo al día (después de instalar programas o tocar algo de `/etc`):
```
~/GitHub/dotfiles/Scripts/backup_system.sh && git -C ~/GitHub/dotfiles add system && git -C ~/GitHub/dotfiles commit -m "Actualizar respaldo del sistema"
```
Luego seguir **Pasos manuales** (al final): lo que no puede ir en un repo público.

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

# Referencia de funciones
Todo lo de abajo vive en este repo; `Super+F1` muestra la lista de atajos en vivo (sale de `i3/config`).

## Atajos de teclado (i3, `Super` = tecla Windows)
| Atajo | Acción |
|---|---|
| `Super+Space` | Lanzador rofi con pestañas APPS / DEVICES / FILES / HEALTH (`←`/`→` cambian de pestaña) |
| `Super+Return` | Terminal (Alacritty) |
| `Super+O` | Menú de energía: bloquear, suspender, **fondo nuevo**, reiniciar, apagar |
| `Super+Shift+E` | Cerrar sesión (con confirmación) |
| `Super+L` | Bloquear pantalla (huella o contraseña) |
| `Super+T` | Tema claro/oscuro |
| `Super+P` | Distribución de teclado latam ↔ us |
| `Super+V` | Historial del portapapeles (CopyQ) |
| `Super+Shift+S` | Captura de pantalla (Flameshot) |
| `Super+N` | Renombrar la ventana (título en modo pestañas/apilado) |
| `Super+F1` | Lista buscable de todos los atajos |
| `Super+Alt+Space` / `Super+Alt+→` / `Super+Alt+←` | Play/pausa, siguiente, anterior (Spotify, navegador, mpv…) |
| `Super+Shift+N` | Encender/apagar la luz nocturna |
| Clic en la batería (polybar) | Alternar límite de carga 80% ↔ una carga completa |
| `Super+D` | dmenu |
| `Super+1…0` / `Super+Shift+1…0` | Ir a / mover ventana a escritorio 1–10 |
| `Super+X` / `Super+Z` | Escritorio siguiente / anterior |
| `Super+<` / `Super+>` | Mover el escritorio al otro monitor |
| `Super+J/K/;` y flechas | Enfocar ventana (con `Shift`: moverla) |
| `Super+H` / `Super+Shift+V` | Dividir horizontal / vertical |
| `Super+W` / `Super+S` / `Super+E` | Pestañas / apilado / alternar división |
| `Super+F` | Pantalla completa |
| `Super+Shift+Space` | Ventana flotante |
| `Super+A` | Enfocar contenedor padre |
| `Super+R` | Modo redimensionar (flechas o J/K/L/;, `Esc` para salir) |
| `Super+Shift+Q` | Cerrar ventana |
| `Super+Shift+C` / `Super+Shift+R` | Recargar / reiniciar i3 |
| `AltGr+H/J/K/L` | Flechas ← ↓ ↑ → (la flecha derecha física de la laptop está dañada) |
| Teclas de volumen, brillo y micrófono | Con barrita en pantalla (`Scripts/osd.sh`); `Super`+volumen = pasos de 1%; el volumen sube hasta 150% (por encima de 100% es amplificación por software; `MAX_VOLUME` en `osd.sh`) |

Escritorios con programa asignado: 1 Firefox · 2 Alacritty · 3 IDEs (CLion, Android Studio, VS Code, Rider) · 4 Thunderbird · 5 Nautilus · 6 Discord/Zoom · 7 Minecraft · 9 Ferdium/Telegram · 10 Spotify.

## Qué arranca con i3
- `theme.sh apply` (tema, fondo, colores), `keyboard.sh` (latam + flechas AltGr), `xset -b` (sin pitido).
- `display.sh auto`: detecta dock / HDMI / solo laptop (ver abajo).
- `battery_guard`, aviso de batería (`batterynotify` cada 5 min) y `photo_wallpaper.sh --daemon`.
- `picom` (transparencias/animaciones, backend glx), `dunst` (notificaciones arriba a la derecha), `copyq`, `nm-applet`, `dex` (autostart XDG: Ferdium).
- `xss-lock` → `lock_screen` al suspender o por inactividad.
- `gammastep` (luz nocturna: pantalla cálida al anochecer en Cartago, `gammastep/config.ini`) y `udiskie` (monta USB solo y avisa).

## Barra (polybar)
Escritorios a la izquierda; al centro la canción que suena (`Scripts/now_playing.sh`: clic = play/pausa, rueda = siguiente/anterior); a la derecha RAM, CPU, volumen, Wi-Fi, distribución de teclado, batería (`Scripts/batterystatus`: ícono según nivel, tiempo restante, rojo ≤15%, 󰂄 cargando, 󰚥 enchufada pero detenida en el límite de 80%; clic = alternar límite/carga completa) y fecha/hora. Colores en `polybar/colors-dark.ini` / `colors-light.ini`; el color de acento lo pone `theme.sh` desde el fondo. `polybar/launch.sh` lanza la barra `main` en la laptop y `secondary` en monitores externos.

## Lanzador y Bluetooth (rofi)
- `rofi/launchers/type-6/launcher.sh` (`Super+Space`): estilo según el tema (style-6 claro, style-7 oscuro con `rofi/images/telescope.png`, que no está en el repo por licencia).
- Pestaña **DEVICES** (`Scripts/rofi_bt_battery.sh`): estilo Apple. Muestra lo conectado (con batería; submenú desconectar/olvidar) y lo cercano ordenado por señal. Un clic conecta, empareja y confía en el dispositivo; si un dispositivo emparejado rechaza la conexión (llave vieja) lo vuelve a emparejar solo.
- Pestaña **HEALTH** (`Scripts/rofi_health.sh`): chequeo del sistema, problemas primero (rojo = problema, ámbar = advertencia, gris = bien). Pacman: actualizaciones pendientes (repos + AUR), última actualización completa, última sincronización, antigüedad del mirrorlist, lock huérfano, consistencia de la base de datos (`pacman -Dk`), huérfanos, `.pacnew`, tamaño de la caché. Sistema: reinicio pendiente por kernel, servicios caídos, disco, memoria, desgaste de baterías, temperatura, hora sincronizada, errores del journal, hibernación y huella. Elegir una fila abre una terminal con el detalle o el arreglo (p. ej. actualizaciones → `paru -Syu`, caché → `paru -Sc`). Muestra el último reporte al instante y lo refresca en segundo plano; las actualizaciones se buscan como `checkupdates` (copia privada de las bases de datos, máximo una vez por hora). En terminal: `rofi_health.sh --print`.
- `rofi/powermenu/type-2/powermenu.sh` (`Super+O`). Las demás carpetas de `rofi/` son la colección original de adi1090x (temas sin usar).

## Pantalla de bloqueo y huella
- `Scripts/lock_screen` (i3lock-color): fondo desenfocado con una tarjeta "de vidrio", reloj y fecha; sigue el tema y el fondo actual; funciona con varios monitores. El sensor escucha todo el tiempo: tocar el sensor **o** escribir la contraseña.
- Huella (sensor Synaptics 06cb:009a de la T480): necesita `python-validity` + `open-fprintd` del AUR (no el `fprintd` normal). `Scripts/setup_fingerprint.sh` los instala y agrega la huella a `sudo` y al bloqueo. Registrar el dedo: `fprintd-enroll`.
- En LightDM (pantalla de inicio): Enter con la contraseña vacía y luego tocar el sensor.
- Si la huella falla **sin tocar el sensor** ("Failed to match" al instante), la calibración del arranque quedó mala (se rehace en cada arranque y se guarda en `/run`). Arreglo sin reiniciar, sin tocar el sensor mientras corre: `sudo rm /run/python-validity/calib-data.bin && sudo systemctl restart python3-validity open-fprintd`. Reiniciar solo el servicio no basta: reutiliza la calibración guardada.

## Batería, suspensión e hibernación
- `Scripts/battery_guard`: con ≤5% (o ≤6 min restantes) muestra una cuenta regresiva de 2 min; conectar el cargador la cancela; al llegar a 0 hiberna (o apaga si no se puede). `battery_guard --test` = prueba de 15 s.
- `Scripts/setup_hibernate.sh` (con sudo, una vez): swapfile de 16G solo para hibernar (zram sigue siendo el swap normal), hook `resume`, `resume=`/`resume_offset=` en GRUB, tapa cerrada → suspender y luego hibernar si la batería se agota, UPower crítico → hibernar, huella en LightDM y fondo de bienvenida (`desktop_bgs/welcome.jpg`). Respaldos `*.bak-hibernate`.
- `Scripts/setup_laptop.sh` (una vez, como tu usuario; pide sudo): **límite de carga** 40–80% en las dos baterías (alarga su vida; queda guardado en la batería, también aplica en Windows), **TLP** (ahorro de energía; excluye el Bluetooth y el lector de huella del autosuspend USB), **throttled** (arregla el bug de la T480 que frena la CPU), **fwupd** (lista actualizaciones de BIOS/Thunderbolt; instalarlas: `fwupdmgr update`, con cargador), temporizadores semanales `paccache` (guarda 2 versiones) y `reflector`, y los paquetes de playerctl, gammastep, udiskie, y rclone.
- `Scripts/battery_charge.sh full|limit|toggle|status`: carga completa una vez (viajes) o volver al límite. Lo usa el clic en la batería; una regla de sudoers permite solo `tlp fullcharge` y `tlp setcharge` sin contraseña.
- `Scripts/goodbye.sh poweroff|reboot|logout`: muestra `desktop_bgs/bye.jpg` 1.8 s antes de apagar/reiniciar/salir.

## Pantallas
`Scripts/display.sh [auto|dock|hdmi|laptop]` (alias `screens`, `dock`, `hdmi`, `solo`): dock = laptop a la izquierda + DP-1-2 horizontal + DP-1-3-1 vertical; hdmi = HDMI-2 a la izquierda + laptop. `Scripts/wallpaper.sh` arma el fondo para todos los monitores (los verticales sin deformar).

## Escritorio remoto a Windows
`windows` (alias de `Scripts/rdp.sh`): abre el escritorio de la PC con Windows 10 Pro (`desktop-qpitifc`) por RDP sobre Tailscale. Funciona en casa (directo por la LAN), en el TEC o con datos móviles, sin abrir puertos. La ventana se adapta a su tamaño, con sonido, micrófono, portapapeles compartido y `~/Public` visible en Windows como unidad "Linux". La primera vez pide el usuario y la contraseña de Windows (con cuenta Microsoft: el correo y la contraseña de la cuenta, no el PIN); la contraseña queda cifrada en el llavero de GNOME (`gnome-keyring`, que instala `setup_laptop.sh` y que se abre solo al iniciar sesión con contraseña) y las siguientes veces conecta sin preguntar. Si Windows la rechaza, la olvida y la vuelve a pedir; tras cambiar la contraseña de Windows: `rdp.sh --forget`. **Cuentas Microsoft:** el usuario debe ir como `MicrosoftAccount\correo@dominio` (p. ej. `MicrosoftAccount\nombre@outlook.com`) y con Kerberos desactivado (`/auth-pkg-list:!kerberos`); si no, FreeRDP toma el correo como usuario de un dominio de empresa y Windows rechaza el inicio de sesión (`ERRCONNECT_LOGON_FAILURE`, "Cannot find KDC for realm"). `rdp.sh` lo hace solo: basta escribir el correo. En Remmina u otro cliente hay que poner el prefijo a mano. Además, Windows solo acepta la contraseña por RDP si alguna vez se entró a esa PC con la contraseña (no solo con PIN). El aviso "host key has changed" de la primera conexión es un fallo de FreeRDP 3 y se oculta. Alternativa gráfica: Remmina.

## Teclado
- Distribución latam (`/etc/X11/xorg.conf.d/00-keyboard.conf`, respaldado en `system/etc/`). Cambiar de distribución siempre con `Scripts/keyboard.sh` / `toggle_layout.sh`: un `setxkbmap` a secas borra las flechas AltGr (`xkb/symbols/arrows`).
- Touchpad: tap, clic con dedos y scroll natural (`30-touchpad.conf`).

## Terminal y shell
- Alacritty: JetBrainsMono Nerd Font 12, tema Catppuccin Mocha (oscuro) / `bone-light.toml` (claro), cambia en vivo con el tema.
- `.bashrc`: prompt `(✿◠‿◠)` con rama de git (`Scripts/.git-prompt-zkwinkle`), `ls` con `eza`, alias de git (`gc`, `gco`, `gbr`, `gsts`, `glog`), `config` (ir al repo), `vim`→`nvim`, `mimir` (bloquear), `off`, `pdf archivo` (abre en Okular), `title "texto"` (título de la ventana).
- `pain [búsqueda]` / `pare [búsqueda]` (en `.bashrc`, extraídos de [zkwinkle](https://github.com/zkwinkle/.config)): instalar / desinstalar paquetes (repos + AUR) con `paru` y búsqueda difusa en `fzf`; `Tab` marca varios, `Enter` confirma. La vista previa muestra la descripción y la info del paquete (`Scripts/_paru_fzf_preview.sh`, enlazado a `~/.local/bin`).
- Neovim: LazyVim (`nvim/`, versiones fijadas en `lazy-lock.json`).
- `.gitconfig`: usuario, `bat` como pager, git-lfs.

## Scripts sin usar
`Scripts/cava.py`, `Scripts/mic.sh` (módulo de micrófono para polybar) y `Scripts/weather.py` (clima de Cartago con OpenWeather; la API key va en `~/.config/openweather/api_key`, fuera del repo) no están conectados a nada ahora mismo.

# Respaldo de secretos
`Scripts/backup_secrets.sh` empaqueta lo que no puede ir en el repo (llaves SSH y GPG, llave de adb, API keys, redes Wi-Fi guardadas) cifrado con gpg AES-256 y una contraseña tuya (**guárdala fuera de la laptop**, en un gestor de contraseñas o en papel: sin ella el respaldo no sirve). Siempre deja copia en `~/Backups/secrets` (últimas 5) y la sube según `~/.config/backup_secrets.conf`:
- `DEST=rclone:gdrive:Backups/secrets`: cualquier nube configurada con `rclone config` (Google Drive, Dropbox, OneDrive, MEGA…).

Restaurar en un sistema nuevo: `backup_secrets.sh restore secrets-AAAAMMDD-HHMM.tar.gpg`. La pestaña HEALTH avisa si nunca se hizo o tiene más de 90 días.

# Pasos manuales
Lo que **no** está en el repo (es público) y hay que rehacer o restaurar:
- Llaves SSH/GPG, redes Wi-Fi y API keys: `backup_secrets.sh restore` (ver arriba; el archivo se baja de tu nube con `rclone` o del USB).
- Redes Wi-Fi (`nmtui`; la de wTEC está arriba) — `/etc/NetworkManager/system-connections` tiene contraseñas.
- Tailscale: `sudo tailscale up` y aprobar el equipo.
- Huella: `fprintd-enroll` después de `setup_fingerprint.sh`.
- API key de OpenWeather en `~/.config/openweather/api_key` (solo si se vuelve a usar `weather.py`).
- Datos de PostgreSQL y OpenLDAP (`slapd`): respaldar con `pg_dumpall` / `slapcat` y restaurar antes de habilitar esos servicios.
- Perfiles de navegador, Thunderbird, Ferdium, Spotify, JetBrains: iniciar sesión / sincronizar.
- Imágenes con licencia que no se pueden publicar: `rofi/images/telescope.png` y `desktop_bgs/premium_photo-*` (si faltan, el lanzador oscuro queda sin imagen).
- Bluetooth: volver a emparejar (teclado Keychron K6, mouse, audífonos JBL, parlante Wonderboom) desde `Super+Space` → DEVICES.

## Pendientes conocidos
- `/etc/systemd/system/lock-screen.service` es un servicio viejo (2025) que systemd rechaza por un `User=` inválido; no hace nada. Borrarlo: `sudo systemctl disable lock-screen.service && sudo rm /etc/systemd/system/lock-screen.service`.
- Quedó un enlace de `waydroid-container.service` de un paquete ya desinstalado: `sudo rm /etc/systemd/system/multi-user.target.wants/waydroid-container.service`.
