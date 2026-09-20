# Usamos la base mínima oficial de Universal Blue que ya incluye drivers universales de AMD, Nvidia e Intel
FROM ghcr.io/ublue-os/bazzite:stable

# Instalamos únicamente la interfaz de consola, emuladores y drivers de controles Bluetooth
RUN rpm-ostree install \
    gamescope \
    retroarch \
    bluez \
    mesa-vulkan-drivers

# Limpiamos cachés para que la imagen final ocupe el menor espacio posible
RUN rpm-ostree cleanup -a
