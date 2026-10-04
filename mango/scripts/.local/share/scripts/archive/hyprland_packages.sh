#!/usr/bin/env bash
set -euo pipefail

packages=(
  hyprpolkitagent
)

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: sudo $(basename "$0")"
    echo "Install common Hyprland helper packages."
    exit 0
fi

command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found." >&2; exit 1; }

sudo pacman -S --needed --noconfirm "${packages[@]}"
echo "Installed: ${packages[*]}"
