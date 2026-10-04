#!/usr/bin/env bash
set -euo pipefail

SERVICES=(hyprpolkitagent waybar)
SYSTEM_SERVICES=(acpid)

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $(basename "$0")"
    echo "Enable common Hyprland-related user services and required system services."
    exit 0
fi

command -v systemctl >/dev/null 2>&1 || { echo "Error: systemctl not found." >&2; exit 1; }

for svc in "${SERVICES[@]}"; do
    systemctl --user enable --now "$svc"
done

for svc in "${SYSTEM_SERVICES[@]}"; do
    sudo systemctl enable --now "$svc"
done

echo "Enabled user services: ${SERVICES[*]}"
echo "Enabled system services: ${SYSTEM_SERVICES[*]}"
