#!/usr/bin/env bash
set -euo pipefail

packages=(
    xonsh
    python-prompt_toolkit
    python-pygments
    python-setproctitle
    python-wcwidth
)

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $(basename "$0")"
    echo "Install xonsh and related packages with yay."
    exit 0
fi

if ! command -v yay >/dev/null 2>&1; then
    echo "yay not found. Installing yay first..." >&2
    command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found." >&2; exit 1; }
    sudo pacman -S --needed --noconfirm yay
fi

echo "Installing ${#packages[@]} packages with yay..."
yay -S --noconfirm "${packages[@]}"
echo "Done."
