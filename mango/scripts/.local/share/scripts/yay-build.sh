#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${1:-yay-bin}"
AUR_URL="https://aur.archlinux.org/${PACKAGE_NAME}.git"
BUILD_DIR=""

usage() {
    echo "Usage: $(basename "$0") [aur-package-name]"
    echo "Build and install an AUR package from a temporary directory."
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
}

cleanup() {
    if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then
        log "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    fi
}

if [[ "$PACKAGE_NAME" == "-h" || "$PACKAGE_NAME" == "--help" ]]; then
    usage
    exit 0
fi

trap cleanup EXIT

for cmd in git mktemp makepkg; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

if command -v yay >/dev/null 2>&1 && [[ "$PACKAGE_NAME" == "yay-bin" ]]; then
    log "yay is already installed. Exiting."
    exit 0
fi

BUILD_DIR="$(mktemp -d)"
log "Created temporary build directory: $BUILD_DIR"
cd "$BUILD_DIR"

log "Cloning $PACKAGE_NAME from AUR..."
git clone "$AUR_URL"
cd "$PACKAGE_NAME"

log "Building and installing $PACKAGE_NAME..."
makepkg -si --noconfirm
log "$PACKAGE_NAME installed successfully"
