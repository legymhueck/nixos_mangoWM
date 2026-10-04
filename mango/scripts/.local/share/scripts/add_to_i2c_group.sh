#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Compatibility wrapper for add-to-i2c-group.sh"
    exec "$SCRIPT_DIR/add-to-i2c-group.sh" --help
fi
exec "$SCRIPT_DIR/add-to-i2c-group.sh" "$@"
