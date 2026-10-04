#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Compatibility wrapper for srcinfo-update.sh"
    exec "$SCRIPT_DIR/srcinfo-update.sh" --help
fi
exec "$SCRIPT_DIR/srcinfo-update.sh" "$@"
