# Usamos la base oficial y minimalista de Arch Linux (Pura y limpia)
FROM archlinux:latest

# Activamos el repositorio multilib (necesario para Steam y drivers de 32 bits)
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Actualizamos e instalamos los componentes junto al Kernel oficial y sudo
# Se agregó ntfs-3g para dar soporte a la lectura/escritura de discos de Windows
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    linux linux-firmware \
    mesa lib32-mesa vulkan-radeon \
    nvidia-utils lib32-nvidia-utils libvdpau libva-utils \
    steam gamescope retroarch \
    bluez bluez-utils networkmanager seatd \
    xorg-server xf86-video-amdgpu parted exfatprogs ntfs-3g sudo \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

# Habilitamos los servicios de conectividad y gestión gráfica esenciales en segundo plano
RUN systemctl enable NetworkManager bluetooth seatd

# === Preconfiguración Regional y Horaria (Tucumán, Argentina) ===
RUN echo "es_AR.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
RUN echo "LANG=es_AR.UTF-8" > /etc/locale.conf
RUN ln -sf /usr/share/zoneinfo/America/Argentina/Tucuman /etc/localtime

# === Configuración de Seguridad y Cuentas ===
# Establecemos contraseña de emergencia para root y creamos usuario 'consola'
RUN echo "root:root" | chpasswd && \
    useradd -m -g users -G wheel,video,input,seat -s /bin/bash consola && \
    passwd -d consola && \
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# === Configurar Autologin en Consola (TTY1) para el usuario 'consola' ===
RUN mkdir -p /etc/systemd/system/getty@tty1.service.d/ && \
    echo -e "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin consola --noclear %I \$TERM" > /etc/systemd/system/getty@tty1.service.d/override.conf

# === Puntos de Montaje para Juegos (Gestionados externamente por el Workflow) ===
# Creamos los directorios vacíos que el archivo fstab del workflow utilizará para montar las unidades
RUN mkdir -p /home/consola/juegos && \
    mkdir -p /home/consola/juegos_windows && \
    chown -R consola:users /home/consola/juegos /home/consola/juegos_windows

# === Creación del Script de Arranque y Configuración de Pantalla ===
RUN mkdir -p /etc/local.d/
RUN echo '#!/bin/bash' > /etc/local.d/consola.start

# Script de expansión de almacenamiento dinámico para la Partición 3
RUN echo 'if [ ! -f /etc/expanded ]; then' >> /etc/local.d/consola.start
RUN echo '    DISK=$(findmnt -n -o SOURCE / | sed -E "s/p?[0-9]+$//")' >> /etc/local.d/consola.start
RUN echo '    sudo parted -s "$DISK" resizepart 3 100%' >> /etc/local.d/consola.start
RUN echo '    touch /etc/expanded' >> /etc/local.d/consola.start
RUN echo 'fi' >> /etc/local.d/consola.start

# Configuración del entorno gráfico y lanzamiento optimizado de Steam GamepadUI
RUN echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /etc/local.d/consola.start
RUN echo 'export LIBSEAT_BACKEND=builtin' >> /etc/local.d/consola.start
RUN echo 'GPU=$(lspci | grep -E "VGA|3D")' >> /etc/local.d/consola.start
RUN echo 'if echo "$GPU" | grep -iq "AMD"; then' >> /etc/local.d/consola.start
RUN echo '    gamescope -e -- steam -gamepadui' >> /etc/local.d/consola.start
RUN echo 'elif echo "$GPU" | grep -iq "NVIDIA"; then' >> /etc/local.d/consola.start
RUN echo '    export __NV_PRIME_RENDER_OFFLOAD=1' >> /etc/local.d/consola.start
RUN echo '    export __GLX_VENDOR_LIBRARY_NAME=nvidia' >> /etc/local.d/consola.start
RUN echo '    gamescope -e -- steam -gamepadui' >> /etc/local.d/consola.start
RUN echo 'fi' >> /etc/local.d/consola.start
RUN chmod +x /etc/local.d/consola.start

# Disparamos el script automáticamente al iniciar sesión en TTY1
RUN echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then' >> /home/consola/.bash_profile
RUN echo '    exec /etc/local.d/consola.start' >> /home/consola/.bash_profile
RUN echo 'fi' >> /home/consola/.bash_profile
RUN chown consola:users /home/consola/.bash_profile

# Limpieza absoluta de archivos temporales de pacman para aligerar la imagen
RUN pacman -Scc --noconfirm
