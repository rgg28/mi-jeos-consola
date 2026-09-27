if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec /home/consola/arrancar_steam.sh
fi
