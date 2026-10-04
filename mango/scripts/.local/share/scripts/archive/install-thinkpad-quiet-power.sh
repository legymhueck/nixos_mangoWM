#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/thinkpad-power-settings.sh"
SCRIPT_TARGET="/usr/local/sbin/thinkpad-power-settings"
SERVICE_TARGET="/etc/systemd/system/thinkpad-quiet-power.service"
SLEEP_HOOK_TARGET="/etc/systemd/system-sleep/thinkpad-quiet-power"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $(basename "$0")

Install thinkpad-power-settings, a systemd service, and a resume hook.
EOF
  exit 0
fi

if [[ ${EUID} -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

if [[ ! -f "$SCRIPT_SOURCE" ]]; then
  echo "Missing source script: $SCRIPT_SOURCE" >&2
  exit 1
fi

if command -v pacman >/dev/null 2>&1 && ! command -v powerprofilesctl >/dev/null 2>&1; then
  pacman -S --needed --noconfirm power-profiles-daemon
fi

install -Dm755 "$SCRIPT_SOURCE" "$SCRIPT_TARGET"

cat > "$SERVICE_TARGET" <<'EOF'
[Unit]
Description=Apply quiet ThinkPad power settings
Wants=power-profiles-daemon.service
After=power-profiles-daemon.service
ConditionPathExists=/usr/local/sbin/thinkpad-power-settings

[Service]
Type=oneshot
Environment=PROFILE=power-saver
Environment=PLATFORM_PROFILE=low-power
Environment=MIN_PERF_PCT=10
Environment=MAX_PERF_PCT=70
Environment=NO_TURBO=1
ExecStart=/usr/local/sbin/thinkpad-power-settings

[Install]
WantedBy=multi-user.target
EOF

install -d /etc/systemd/system-sleep
cat > "$SLEEP_HOOK_TARGET" <<'EOF'
#!/bin/sh
case "$1" in
  post)
    /usr/local/sbin/thinkpad-power-settings >/dev/null 2>&1 || true
    ;;
esac
EOF
chmod 755 "$SLEEP_HOOK_TARGET"

systemctl daemon-reload
systemctl enable --now power-profiles-daemon.service
systemctl enable --now thinkpad-quiet-power.service
/usr/local/sbin/thinkpad-power-settings

echo "Installed: $SCRIPT_TARGET"
echo "Installed: $SERVICE_TARGET"
echo "Installed: $SLEEP_HOOK_TARGET"
echo "Quiet power profile is active and will be re-applied after reboot and resume."
