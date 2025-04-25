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
¨¨¨
timedatectl set-timezone America/Costa_Rica
¨¨¨

# Keyboard lang=latam
```
setxkbmap -layout latam
```

# Scroll direction - Mousetrack
