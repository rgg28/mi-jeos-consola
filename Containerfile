# Usamos la base oficial y minimalista de Arch Linux (Pura y limpia)
FROM archlinux:latest

# Actualizamos repositorios e instalamos solo los drivers universales, Steam y RetroArch
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    mesa lib32-mesa vulkan-radeon \
    nvidia-utils lib32-nvidia-utils \
    steam gamescope retroarch bluez \
    xorg-server xf86-video-amdgpu

# Creamos el script de arranque directo a Steam Big Picture de forma limpia
RUN mkdir -p /etc/local.d/
RUN echo '#!/bin/bash' > /etc/local.d/consola.start
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
