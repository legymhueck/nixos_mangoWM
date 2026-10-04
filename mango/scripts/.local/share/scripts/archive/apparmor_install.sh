#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0")

Install AppArmor userspace tools and enable apparmor.service.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "This script is intended for Arch Linux (pacman not found)." >&2
    exit 1
fi

echo "Installing AppArmor userspace tools..."
sudo pacman -S --needed --noconfirm apparmor

echo "Enabling and starting apparmor.service..."
sudo systemctl enable --now apparmor.service

echo "Done."
echo "If AppArmor is not active after reboot, ensure your kernel cmdline includes:"
echo "  lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
echo "Then reboot and verify with: aa-enabled && sudo aa-status"
