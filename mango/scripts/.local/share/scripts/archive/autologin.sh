#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-$(id -un)}}"
FILE_PATH="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
TMP_FILE="$(mktemp)"

usage() {
    cat <<EOF
Usage: $(basename "$0") [username]

Configures tty1 autologin for the specified user.
Defaults to:
  1. first argument
  2. SUDO_USER when run via sudo
  3. current user
EOF
}

if [[ "$TARGET_USER" == "-h" || "$TARGET_USER" == "--help" ]]; then
    usage
    exit 0
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "Error: user not found: $TARGET_USER" >&2
    exit 1
fi

cat > "$TMP_FILE" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $TARGET_USER %I \$TERM
EOF

sudo install -D -m 0644 "$TMP_FILE" "$FILE_PATH"
rm -f "$TMP_FILE"

sudo systemctl daemon-reload

echo "Configured tty1 autologin for '$TARGET_USER' in $FILE_PATH"
