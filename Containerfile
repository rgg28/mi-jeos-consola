# === Base Oficial Arch Linux ===
FROM archlinux:latest

# Activamos el repositorio multilib
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Actualizamos e instalamos componentes (Se agregan mkinitcpio y xorg-xinit)
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
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
RUN mkdir -p /home/consola/juegos /home/consola/juegos_windows && \
    chown -R consola:users /home/consola/juegos /home/consola/juegos_windows

# === Forzar carga temprana de drivers gráficos (KMS Universal) ===
RUN sed -i 's/^MODULES=()/MODULES=(amdgpu i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

# === Script de Arranque Dinámico Multi-Hardware ===
RUN echo '#!/bin/bash' > /home/consola/arrancar_steam.sh && \
    echo 'if [ ! -f /home/consola/.expanded ]; then' >> /home/consola/arrancar_steam.sh && \
    echo '    DISK=$(findmnt -n -o SOURCE / | sed -E "s/p?[0-9]+$//")' >> /home/consola/arrancar_steam.sh && \
    echo '    sudo parted -s "$DISK" resizepart 3 100%' >> /home/consola/arrancar_steam.sh && \
    echo '    touch /home/consola/.expanded' >> /home/consola/arrancar_steam.sh && \
    echo 'fi' >> /home/consola/arrancar_steam.sh && \
    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/consola/arrancar_steam.sh && \
    echo 'export LIBSEAT_BACKEND=builtin' >> /home/consola/arrancar_steam.sh && \
    echo 'GPU=$(lspci | grep -E "VGA|3D")' >> /home/consola/arrancar_steam.sh && \
    echo 'if echo "$GPU" | grep -iq "NVIDIA"; then' >> /home/consola/arrancar_steam.sh && \
    echo '    export __NV_PRIME_RENDER_OFFLOAD=1' >> /home/consola/arrancar_steam.sh && \
    echo '    export __GLX_VENDOR_LIBRARY_NAME=nvidia' >> /home/consola/arrancar_steam.sh && \
    echo '    startx /usr/bin/steam -gamepadui -- -keeptty' >> /home/consola/arrancar_steam.sh && \
    echo 'else' >> /home/consola/arrancar_steam.sh && \
    echo '    gamescope -e -- steam -gamepadui' >> /home/consola/arrancar_steam.sh && \
    echo 'fi' >> /home/consola/arrancar_steam.sh && \
    chmod +x /home/consola/arrancar_steam.sh && \
    chown consola:users /home/consola/arrancar_steam.sh

# Disparador automático en .bash_profile
RUN echo 'if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then' > /home/consola/.bash_profile && \
    echo '    exec /home/consola/arrancar_steam.sh' >> /home/consola/.bash_profile && \
    echo 'fi' >> /home/consola/.bash_profile && \
    chown consola:users /home/consola/.bash_profile

RUN pacman -Scc --noconfirm
