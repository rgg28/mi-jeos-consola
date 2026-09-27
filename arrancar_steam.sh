#!/bin/bash
TESTIGO="/home/consola/.partition_expanded"

if [ ! -f "$TESTIGO" ]; then
    DISK=$(findmnt -n -o SOURCE / | sed -E 's/(p[0-9]| [0-9])$//' | sed -E 's/[0-9]+$//')
    if [ -b "${DISK}3" ] || [ -b "${DISK}p3" ]; then
        PART="${DISK}3"
        [ -b "${DISK}p3" ] && PART="${DISK}p3"
        sudo parted -s "$DISK" resizepart 3 100%
        sudo mkfs.exfat -U ebd0a0a2-b9e5-4433-87c0-68b6b72699c7 "$PART"
        sudo touch "$TESTIGO" && sudo chown consola:users "$TESTIGO"
        sudo mount -a
    fi
fi

contador=0
carpetas=("disco_C" "disco_D" "disco_E")
for dev in $(lsblk -no NAME,FSTYPE,PARTUUID | grep -E "ntfs|vfat" | grep -v "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7" | awk '{print $1}'); do
    actual_dev="/dev/$dev"
    if ! findmnt -n "$actual_dev" > /dev/null && [ $contador -lt 3 ]; then
        folder="/home/consola/discos_windows/${carpetas[$contador]}"
        sudo mkdir -p "$folder"
        sudo mount -t ntfs3 -o defaults,noatime,uid=1000,gid=100,umask=000 "$actual_dev" "$folder" 2>/dev/null || sudo mount "$actual_dev" "$folder" 2>/dev/null
        ((contador++))
    fi
done

export XDG_RUNTIME_DIR=/run/user/$(id -u)
export LIBSEAT_BACKEND=builtin

GPU=$(lspci | grep -E "VGA|3D")
if echo "$GPU" | grep -iq "NVIDIA"; then
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    
    echo -e '#!/bin/sh\nMONITOR=$(xrandr | grep " connected" | awk "{print \$1}" | head -n 1)\nRESOLUCION=$(xrandr | grep -A 1 "$MONITOR" | tail -n 1 | awk "{print \$1}")\nxrandr --output "$MONITOR" --mode "$RESOLUCION"\nexec gamemoderun steam -gamepadui' > /home/consola/.xinitrc
    chmod +x /home/consola/.xinitrc
    startx /home/consola/.xinitrc -- -keeptty
else
    gamescope -e -f -- gamemoderun steam -gamepadui
fi
