#!/bin/bash
TESTIGO="/home/consola/.partition_expanded"

# 1. Asegurar que XDG_RUNTIME_DIR exista físicamente y tenga los permisos correctos
export XDG_RUNTIME_DIR=/run/user/$(id -u)
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    sudo mkdir -p "$XDG_RUNTIME_DIR"
    sudo chown consola:users "$XDG_RUNTIME_DIR"
    sudo chmod 700 "$XDG_RUNTIME_DIR"
fi

# 2. Expansión automática de la partición de juegos en el primer arranque
if [ ! -f "$TESTIGO" ]; then
    DISK=$(findmnt -n -o SOURCE / | sed -E 's/(p[0-9]| [0-9])$//' | sed -E 's/[0-9]+$//')
    if [ -b "${DISK}3" ] || [ -b "${DISK}p3" ]; then
        PART="${DISK}3"
        [ -b "${DISK}p3" ] && PART="${DISK}p3"
        sudo parted -s "$DISK" resizepart 3 100%
        # Forzamos el UUID exacto de la partición para que coincida con el genimage del workflow
        sudo mkfs.exfat -U ebd0a0a2-b9e5-4433-87c0-68b6b72699c7 "$PART"
        sudo touch "$TESTIGO" && sudo chown consola:users "$TESTIGO"
        sudo mount -a
    fi
fi

# 3. Automontaje de discos Windows (NTFS/VFAT) - Corregido filtro Case-Insensitive para el UUID
contador=0
carpetas=("disco_C" "disco_D" "disco_E")
for dev in $(lsblk -no NAME,FSTYPE,PARTUUID | grep -E "ntfs|vfat" | grep -iv "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7" | awk '{print $1}'); do
    actual_dev="/dev/$dev"
    if ! findmnt -n "$actual_dev" > /dev/null && [ $contador -lt 3 ]; then
        folder="/home/consola/discos_windows/${carpetas[$contador]}"
        sudo mkdir -p "$folder"
        sudo mount -t ntfs3 -o defaults,noatime,uid=1000,gid=100,umask=000 "$actual_dev" "$folder" 2>/dev/null || sudo mount "$actual_dev" "$folder" 2>/dev/null
        ((contador++))
    fi
done

# 4. Variables de entorno necesarias para Sesiones portátiles de Steam
export LIBSEAT_BACKEND=builtin
export XDG_SESSION_TYPE=wayland
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

# Iniciar bus de dbus de usuario si no existe (vital para audio Pipewire y bluetooth en Steam)
if [ ! -S "$XDG_RUNTIME_DIR/bus" ]; then
    dbus-daemon --session --address=$DBUS_SESSION_BUS_ADDRESS --nofork --nopidfile &
fi

# 5. Detección de GPU y ejecución de la interfaz de juego
GPU=$(lspci | grep -E "VGA|3D")

if echo "$GPU" | grep -iq "NVIDIA"; then
    # Configuración optimizada para NVIDIA (Usa Servidor X nativo sin pasar por intermediarios conflictivos)
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    
    echo -e '#!/bin/sh\nexport XDG_RUNTIME_DIR=/run/user/1000\nexec gamemoderun steam -gamepadui' > /home/consola/.xinitrc
    chmod +x /home/consola/.xinitrc
    
    # Lanzamos xinit directamente evitando las restricciones de seguridad de startx
    xinit /home/consola/.xinitrc -- :0 -keeptty vt1
else
    # Configuración para AMD / Intel (Gamescope puro al estilo Steam Deck)
    # Agregamos parámetros -e (Soporte Steam Integration) y -f (Full screen nativo)
    exec gamescope -e -f -- gamemoderun steam -gamepadui
fi
