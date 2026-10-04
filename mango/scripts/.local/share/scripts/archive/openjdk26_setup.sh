#!/usr/bin/env bash
set -euo pipefail

TARGET_ENV="${TARGET_ENV:-java-26-openjdk}"
PACKAGE_NAME="${PACKAGE_NAME:-jdk-openjdk}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $(basename "$0")"
    echo "Install OpenJDK and set the default Arch Java environment."
    echo "Environment: TARGET_ENV=$TARGET_ENV PACKAGE_NAME=$PACKAGE_NAME"
    exit 0
fi

command -v pacman >/dev/null 2>&1 || { echo "This script is intended for Arch Linux (pacman not found)." >&2; exit 1; }
command -v archlinux-java >/dev/null 2>&1 || { echo "Error: archlinux-java not found." >&2; exit 1; }

echo "Installing $PACKAGE_NAME..."
sudo pacman -S --needed --noconfirm "$PACKAGE_NAME"

echo "Checking installed Java environments..."
if ! archlinux-java status | grep -q "${TARGET_ENV}"; then
    echo "Java environment ${TARGET_ENV} is not available after installation." >&2
    echo "Available environments:" >&2
    archlinux-java status >&2
    exit 1
fi

echo "Setting ${TARGET_ENV} as default..."
sudo archlinux-java set "${TARGET_ENV}"

echo "Done. Current Java status:"
archlinux-java status
