# Si estamos en la terminal virtual 1 (tty1) y no hay ningún entorno gráfico corriendo, arranca Steam
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
    exec /home/consola/arrancar_steam.sh
fi
