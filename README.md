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



