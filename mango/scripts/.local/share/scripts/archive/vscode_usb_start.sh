#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0")

Install the VS Code USB launcher and desktop entry system-wide.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="/usr/local/share/applications"

sudo install -D -m 755 "$SCRIPT_DIR/vscode-usb.sh" /usr/local/bin/vscode-usb.sh
sudo install -D -m 644 "$SCRIPT_DIR/vscode-usb-fast.desktop" "$DESKTOP_DIR/vscode-usb-fast.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo "Installed: /usr/local/bin/vscode-usb.sh"
echo "Installed: $DESKTOP_DIR/vscode-usb-fast.desktop"
