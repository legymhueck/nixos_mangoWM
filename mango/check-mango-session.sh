#!/bin/bash
set -u

ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ERR]\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "command present: $cmd"
  else
    err "command missing: $cmd"
  fi
}

check_file_line() {
  local file="$1"
  local line="$2"
  if [ ! -f "$file" ]; then
    err "file missing: $file"
    return
  fi

  if rg -Fxq "$line" "$file" 2>/dev/null; then
    ok "file contains: $line ($file)"
  else
    err "file missing line: $line ($file)"
  fi
}

check_user_service() {
  local svc="$1"
  local state
  state=$(systemctl --user is-active "$svc" 2>/dev/null || true)
  if [ "$state" = "active" ]; then
    ok "user service active: $svc"
  else
    warn "user service not active: $svc (${state:-unknown})"
  fi
}

check_system_service() {
  local svc="$1"
  local state
  state=$(systemctl is-active "$svc" 2>/dev/null || true)
  if [ "$state" = "active" ]; then
    ok "system service active: $svc"
  else
    warn "system service not active: $svc (${state:-unknown})"
  fi
}

info "Session"
printf '  USER=%s\n' "$USER"
printf '  XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-}"
printf '  XDG_CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-}"
printf '  XDG_SESSION_DESKTOP=%s\n' "${XDG_SESSION_DESKTOP:-}"
printf '  WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
printf '  DISPLAY=%s\n' "${DISPLAY:-}"
printf '  XDG_VTNR=%s\n' "${XDG_VTNR:-}"
printf '  DBUS_SESSION_BUS_ADDRESS=%s\n' "${DBUS_SESSION_BUS_ADDRESS:-}"

if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  ok "Wayland session detected"
else
  warn "Session type is not wayland"
fi

if [ "${XDG_CURRENT_DESKTOP:-}" = "mango" ]; then
  ok "XDG_CURRENT_DESKTOP is mango"
else
  warn "XDG_CURRENT_DESKTOP is '${XDG_CURRENT_DESKTOP:-}'"
fi

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  ok "WAYLAND_DISPLAY is set"
else
  err "WAYLAND_DISPLAY is not set"
fi

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  ok "D-Bus session bus address is set"
else
  err "D-Bus session bus address is not set"
fi

info "Commands"
check_cmd mango
check_cmd dbus-run-session
check_cmd dbus-update-activation-environment
check_cmd systemctl
check_cmd loginctl

info "Packages"
check_cmd gnome-keyring-daemon
check_cmd pipewire
check_cmd wireplumber
check_cmd xdg-desktop-portal
check_cmd rtkit-daemon

info "Portal config"
PORTAL_CONF="${HOME}/.config/xdg-desktop-portal/mango-portals.conf"
check_file_line "$PORTAL_CONF" "default=gtk"
check_file_line "$PORTAL_CONF" "org.freedesktop.impl.portal.ScreenCast=wlr"
check_file_line "$PORTAL_CONF" "org.freedesktop.impl.portal.Screenshot=wlr"

info "Services"
check_user_service dbus-broker.service
check_user_service pipewire.service
check_user_service pipewire-pulse.service
check_user_service wireplumber.service
check_user_service xdg-desktop-portal.service
check_user_service xdg-desktop-portal-gtk.service
check_system_service rtkit-daemon.service

info "Processes"
pgrep -af '(^|/)(mango|gnome-keyring-daemon|pipewire|wireplumber|xdg-desktop-portal)($| )' || warn "expected session processes not found"

info "loginctl"
loginctl show-session "${XDG_SESSION_ID:-self}" -p Name -p Type -p Class -p State -p VTNr 2>/dev/null || warn "could not query loginctl for current session"

info "Recent warnings/errors"
journalctl --user -b --no-pager 2>/dev/null | rg -i 'mango|warning|warn|rtkit|keyring|portal|pipewire|wireplumber|dbus' | tail -n 80 || warn "no matching user journal lines found"
