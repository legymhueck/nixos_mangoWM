#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $(basename "$0")"
    echo "Run inside an Arch package directory to regenerate .SRCINFO"
    exit 0
fi

command -v makepkg >/dev/null 2>&1 || { echo "Error: makepkg not found." >&2; exit 1; }
[[ -f PKGBUILD ]] || { echo "Error: PKGBUILD not found in $(pwd)" >&2; exit 1; }

makepkg --printsrcinfo > .SRCINFO
echo "Wrote $(pwd)/.SRCINFO"
