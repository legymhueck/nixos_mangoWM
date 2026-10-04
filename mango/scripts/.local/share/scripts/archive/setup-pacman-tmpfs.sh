#!/usr/bin/env bash
set -euo pipefail

PACMAN_CACHE_DIR="/tmp/pacman-cache"
PACMAN_CONF="/etc/pacman.conf"
FSTAB="/etc/fstab"
FSTAB_ENTRY="tmpfs $PACMAN_CACHE_DIR tmpfs size=2G,mode=1755 0 0"
PACMAN_TMP="$(mktemp)"
FSTAB_TMP="$(mktemp)"
MOUNTED_BY_SCRIPT=0
CHANGES_COMMITTED=0

cleanup() {
    local exit_status=$?
    trap - EXIT

    rm -f "$PACMAN_TMP" "$FSTAB_TMP"

    if [[ "$CHANGES_COMMITTED" -eq 0 && "$MOUNTED_BY_SCRIPT" -eq 1 ]] && mountpoint -q "$PACMAN_CACHE_DIR"; then
        umount "$PACMAN_CACHE_DIR" || true
    fi

    exit "$exit_status"
}

trap cleanup EXIT

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: sudo $(basename "$0")

Move pacman's cache directory to a tmpfs mount and persist the mount via /etc/fstab.
EOF
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "Error: run as root (sudo $0)" >&2
    exit 1
fi

for cmd in awk findmnt install mount mountpoint cp grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command is missing: $cmd" >&2
        exit 1
    fi
done

mkdir -p "$PACMAN_CACHE_DIR"

ACTIVE_CACHEDIR_COUNT=$(awk '/^[[:space:]]*CacheDir[[:space:]]*=/ { count++ } END { print count + 0 }' "$PACMAN_CONF")
if (( ACTIVE_CACHEDIR_COUNT > 1 )); then
    echo "Error: $PACMAN_CONF contains multiple active CacheDir entries; refusing to rewrite it automatically." >&2
    exit 1
fi

EXISTING_CACHEDIR=$(awk -F= '/^[[:space:]]*CacheDir[[:space:]]*=/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
    print $2
    exit
}' "$PACMAN_CONF")

if [[ -n "$EXISTING_CACHEDIR" && "$EXISTING_CACHEDIR" != "$PACMAN_CACHE_DIR" && "$EXISTING_CACHEDIR" == *[[:space:]]* ]]; then
    echo "Error: existing CacheDir value appears to contain multiple paths; refusing to rewrite it automatically." >&2
    exit 1
fi

awk -v cache_dir="$PACMAN_CACHE_DIR" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*CacheDir[[:space:]]*=/ {
        if (!replaced) {
            print "CacheDir = " cache_dir
            replaced = 1
        }
        next
    }
    { print }
    END {
        if (!replaced) {
            print ""
            print "CacheDir = " cache_dir
        }
    }
' "$PACMAN_CONF" > "$PACMAN_TMP"

cp -a "$FSTAB" "$FSTAB_TMP"
if ! grep -Fxq "$FSTAB_ENTRY" "$FSTAB_TMP"; then
    printf '%s\n' "$FSTAB_ENTRY" >> "$FSTAB_TMP"
fi

findmnt --verify --tab-file "$FSTAB_TMP" >/dev/null

if ! mountpoint -q "$PACMAN_CACHE_DIR"; then
    mount -t tmpfs -o size=2G,mode=1755 tmpfs "$PACMAN_CACHE_DIR"
    MOUNTED_BY_SCRIPT=1
    echo "Mounted tmpfs at $PACMAN_CACHE_DIR"
else
    echo "Already mounted at $PACMAN_CACHE_DIR"
fi

if command -v pacman-conf >/dev/null 2>&1; then
    pacman-conf --config "$PACMAN_TMP" >/dev/null
fi

cp -a "$PACMAN_CONF" "${PACMAN_CONF}.bak.$(date +%s)"
cp -a "$FSTAB" "${FSTAB}.bak.$(date +%s)"
install -m 0644 "$PACMAN_TMP" "$PACMAN_CONF"
install -m 0644 "$FSTAB_TMP" "$FSTAB"
CHANGES_COMMITTED=1

if grep -Fxq "$FSTAB_ENTRY" "$FSTAB"; then
    echo "Ensured tmpfs entry exists in $FSTAB"
fi

echo "Done. Pacman cache is now in RAM."
echo "Note: Packages will not persist across reboots."