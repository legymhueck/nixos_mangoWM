#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${SUDO_USER:-$(id -un)}"
SUDOERS_FILE="/etc/sudoers.d/00_${USER_NAME}"
RULE="${USER_NAME} ALL=(ALL:ALL) ALL"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--nopasswd]

Create a per-user sudoers drop-in for the invoking user.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
	echo "Error: resolved username '$USER_NAME' is invalid." >&2
	exit 1
fi

if [[ "${1:-}" == "--nopasswd" ]]; then
	RULE="${USER_NAME} ALL=(ALL:ALL) NOPASSWD:ALL"
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT
printf '%s\n' "$RULE" > "$TMP_FILE"

sudo visudo -cf "$TMP_FILE"
sudo install -m 0440 "$TMP_FILE" "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE"

echo "Updated $SUDOERS_FILE"
