# === Base Oficial Arch Linux ===
FROM archlinux:latest

# Activamos el repositorio multilib
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# 1. Actualización limpia del sistema base primero
RUN pacman -Syu --noconfirm

# 2. Instalamos la fuente tipográfica y los archivos de idioma base para evitar prompts y errores
# CORRECCIÓN: Añadido 'glibc-locales' para restaurar soporte regional eliminado en imágenes base mínimas
RUN pacman -S --noconfirm gnu-free-fonts glibc glibc-locales

# 3. Instalamos el resto de los componentes junto al Kernel y soporte universal de Xorg
RUN pacman -S --noconfirm \
    linux linux-firmware mkinitcpio parted \
    mesa lib32-mesa vulkan-radeon \
    nvidia-utils lib32-nvidia-utils libvdpau libva-utils \
    steam gamescope retroarch \
    bluez bluez-utils networkmanager seatd \
    xorg-server xorg-xinit xf86-video-amdgpu exfatprogs ntfs-3g sudo \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

# Habilitamos servicios esenciales
RUN systemctl enable NetworkManager bluetooth seatd

# === Preconfiguración Regional (Tucumán, Argentina) ===
RUN echo "es_AR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
RUN echo "LANG=es_AR.UTF-8" > /etc/locale.conf
RUN ln -sf /usr/share/zoneinfo/America/Argentina/Tucuman /etc/localtime

# === Configuración de Cuentas y Seguridad ===
RUN echo "root:root" | chpasswd && \
    useradd -m -g users -G wheel,video,input,seat -s /bin/bash consola && \
    passwd -d consola && \
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# Asignar capacidades a gamescope para ejecución segura sin root
RUN setcap 'cap_sys_nice+ep' /usr/bin/gamescope

# === Autologin en TTY1 para el usuario 'consola' ===
RUN mkdir -p /etc/systemd/system/getty@tty1.service.d/ && \
    echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin consola --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf

# === Puntos de Montaje para Juegos ===
RUN mkdir -p /home/consola/juegos /home/consola/discos_windows && \
    chown -R consola:users /home/consola/juegos /home/consola/discos_windows

# === Forzar carga temprana de drivers gráficos (KMS Universal) ===
RUN sed -i 's/^MODULES=()/MODULES=(amdgpu i915)/' /etc/mkinitcpio.conf

# === Script de Arranque Dinámico Multi-Hardware con Auto-Montaje de Discos ===
RUN cat << 'EOF' > /home/consola/arrancar_steam.sh
#!/bin/bash
if [ ! -f /home/consola/.expanded ]; then
    DISK=$(findmnt -n -o SOURCE / | sed -E "s/p?[0-9]+$//")
    sudo parted -s "$DISK" resizepart 3 100%
    touch /home/consola/.expanded
fi

# === AUTO-MONTAJE EN CALIENTE DE DISCOS WINDOWS ===
contador=0
carpetas=("disco_C" "disco_D" "disco_E")
for dev in $(lsblk -no NAME,FSTYPE | grep -E "ntfs|vfat" | awk '{print $1}'); do
    actual_dev="/dev/$dev"
    if ! findmnt -n "$actual_dev" > /dev/null; then
        folder="/home/consola/discos_windows/${carpetas[$contador]}"
        sudo mount -t ntfs3 -o defaults,noatime,uid=1000,gid=985,umask=000 "$actual_dev" "$folder" 2>/dev/null || sudo mount "$actual_dev" "$folder" 2>/dev/null
        ((contador++))
    fi
done
# ===================================================

export XDG_RUNTIME_DIR=/run/user/$(id -u)
export LIBSEAT_BACKEND=builtin

GPU=$(lspci | grep -E "VGA|3D")
if echo "$GPU" | grep -iq "NVIDIA"; then
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    startx /usr/bin/steam -gamepadui -- -keeptty
else
    # OPTIMIZADO PARA MONITORES 1920x1080 FULL HD:
    # -w 1920 -h 1080: Resolución final de salida en tu monitor.
    # -W 1920 -H 1080: Resolución con la que renderiza la interfaz de Steam.
    gamescope -w 1920 -h 1080 -W 1920 -H 1080 -e -- steam -gamepadui
fi
EOF

# Aplicamos los permisos correspondientes al script de Steam
RUN chmod +x /home/consola/arrancar_steam.sh && \
    chown consola:users /home/consola/arrancar_steam.sh

# === Disparador automático en .bash_profile ===
RUN cat << 'EOF' > /home/consola/.bash_profile
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec /home/consola/arrancar_steam.sh
fi
EOF

# Aplicamos los permisos correspondientes al perfil de Bash
RUN chown consola:users /home/consola/.bash_profile

# === Reglas Udev para Soporte Completo de Mandos (Steam Input) ===
RUN cat << 'EOF' > /etc/udev/rules.d/70-steam-input.rules
# Mando de Xbox 360 / Xbox One / Series X|S
KERNEL=="uinput", MODE="0660", OPTIONS+="static_node=uinput"
KERNEL=="js*", MODE="0664"

# Mandos de PlayStation (DualShock 4 / DualSense 5)
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"

# Mandos de Nintendo Switch (Pro Controller / Joy-Cons)
SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2009", MODE="0666"
EOF

# Limpieza de caché para reducir el tamaño final de la imagen de Docker
RUN pacman -Scc --noconfirm
