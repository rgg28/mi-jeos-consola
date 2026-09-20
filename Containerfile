# Usamos la base oficial y minimalista de Arch Linux (Pura y limpia)
FROM archlinux:latest

# Actualizamos repositorios e instalamos solo los drivers universales, Steam y RetroArch
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    mesa lib32-mesa vulkan-radeon \
    nvidia-utils lib32-nvidia-utils \
    steam gamescope retroarch bluez \
    xorg-server xf86-video-amdgpu

# Creamos el script para que arranque directamente en modo consola al encender
RUN mkdir -p /etc/local.d/
echo -e '#!/bin/bash\nGPU=$(lspci | grep -E "VGA|3D")\nif echo "$GPU" | grep -iq "AMD"; then\n    gamescope -e -- steam -tenfoot\nelif echo "$GPU" | grep -iq "NVIDIA"; then\n    export __NV_PRIME_RENDER_OFFLOAD=1\n    gamescope -e -- steam -tenfoot\nfi' > /etc/local.d/consola.start && \
chmod +x /etc/local.d/consola.start

# Limpieza absoluta de temporales para reducir el peso al mínimo
RUN pacman -Scc --noconfirm
