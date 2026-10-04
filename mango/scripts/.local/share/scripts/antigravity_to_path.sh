#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Compatibility wrapper for antigravity-to-path.sh"
    exec "$SCRIPT_DIR/antigravity-to-path.sh" --help
fi
exec "$SCRIPT_DIR/antigravity-to-path.sh" "$@"
