#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0")

Create a basic profile-sync-daemon config and enable psd.service for the user.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${XDG_CONFIG_HOME:=$HOME/.config}"

PSD_CONF_DIR="$XDG_CONFIG_HOME/psd"
PSD_CONF="$PSD_CONF_DIR/psd.conf"

mkdir -p "$PSD_CONF_DIR"

if [[ ! -f "$PSD_CONF" ]]; then
  cat > "$PSD_CONF" <<'EOF'
# Profile-sync-daemon config
BROWSERS=(chromium opera)
EOF
  echo "Wrote $PSD_CONF"
else
  echo "$PSD_CONF already exists, skipping"
fi

systemctl --user enable --now psd.service
echo "psd.service enabled and started"
