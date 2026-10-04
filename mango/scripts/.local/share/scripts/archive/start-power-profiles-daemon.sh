#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0")

Enable and start power-profiles-daemon, after checking for common conflicts.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "Error: systemctl is not available on this system." >&2
    exit 1
fi

if ! systemctl cat power-profiles-daemon.service >/dev/null 2>&1; then
    echo "Error: power-profiles-daemon.service is not installed." >&2
    exit 1
fi

for conflicting in tlp.service tlp-sleep.service; do
    if systemctl is-active --quiet "$conflicting" 2>/dev/null; then
        echo "Warning: $conflicting is running. It conflicts with power-profiles-daemon." >&2
        echo "Stop and disable it first: sudo systemctl stop --now $conflicting" >&2
        exit 1
    fi
done

sudo systemctl unmask power-profiles-daemon.service
sudo systemctl enable --now power-profiles-daemon.service

if systemctl is-active --quiet power-profiles-daemon.service; then
    echo "power-profiles-daemon is running."
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl list
    fi
else
    echo "Error: power-profiles-daemon failed to start." >&2
    if command -v journalctl >/dev/null 2>&1; then
        sudo journalctl -u power-profiles-daemon.service -n 20 --no-pager || true
    fi
    exit 1
fi
