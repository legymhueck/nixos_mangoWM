#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: sudo $(basename "$0")"
    echo "Uncomments de_DE.UTF-8 in /etc/locale.gen"
    exit 0
fi

sudo sed -i 's/^#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
echo "Enabled de_DE.UTF-8 in /etc/locale.gen"
