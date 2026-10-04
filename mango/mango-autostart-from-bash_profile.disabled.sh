# Start Mango automatically on tty1 with a proper D-Bus/systemd user session.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = "1" ]; then
  export XDG_SESSION_TYPE=wayland
  export XDG_CURRENT_DESKTOP=mango
  export XDG_SESSION_DESKTOP=mango
  exec dbus-run-session bash -lc '
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=mango
    export XDG_SESSION_DESKTOP=mango
    systemctl --user import-environment XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
    dbus-update-activation-environment --systemd XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS
    exec mango
  '
fi
