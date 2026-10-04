#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Compatibility wrapper for ufw-libvirt.sh"
    exec "$SCRIPT_DIR/ufw-libvirt.sh" --help
fi
exec "$SCRIPT_DIR/ufw-libvirt.sh" "$@"
