# Usamos la base oficial y minimalista de Arch Linux (Pura y limpia)
FROM archlinux:latest

# Activamos el repositorio multilib (necesario para Steam y drivers de 32 bits)
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Actualizamos repositorios e instalamos los drivers universales, Steam, RetroArch y herramientas de disco
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    mesa lib32-mesa vulkan-radeon \
    nvidia-utils lib32-nvidia-utils \
    steam gamescope retroarch bluez \
    xorg-server xf86-video-amdgpu parted exfatprogs

# Creamos el script de arranque que expande la partición de juegos al 100% en el primer encendido
RUN mkdir -p /etc/local.d/
RUN echo '#!/bin/bash' > /etc/local.d/consola.start
# El script detecta el tamaño real de tu USB, expande la partición exFAT al máximo y repara la estructura al vuelo
RUN echo 'if [ ! -f /etc/expanded ]; then' >> /etc/local.d/consola.start
RUN echo '    parted -s $(findmnt -n -o SOURCE /) resizepart 2 100%' >> /etc/local.d/consola.start
RUN echo '    fsck.exfat -a $(findmnt -n -o SOURCE / | sed "s/[0-9]//g")2 || true' >> /etc/local.d/consola.start
RUN echo '    touch /etc/expanded' >> /etc/local.d/consola.start
RUN echo 'fi' >> /etc/local.d/consola.start
# Luego inicia Steam Big Picture detectando tu gráfica Ryzen/Nvidia
RUN echo 'GPU=$(lspci | grep -E "VGA|3D")' >> /etc/local.d/consola.start
RUN echo 'if echo "$GPU" | grep -iq "AMD"; then' >> /etc/local.d/consola.start
RUN echo '    gamescope -e -- steam -tenfoot' >> /etc/local.d/consola.start
RUN echo 'elif echo "$GPU" | grep -iq "NVIDIA"; then' >> /etc/local.d/consola.start
RUN echo '    export __NV_PRIME_RENDER_OFFLOAD=1' >> /etc/local.d/consola.start
RUN echo '    gamescope -e -- steam -tenfoot' >> /etc/local.d/consola.start
RUN echo 'fi' >> /etc/local.d/consola.start
RUN chmod +x /etc/local.d/consola.start

# Limpieza absoluta de archivos temporales
RUN pacman -Scc --noconfirm
