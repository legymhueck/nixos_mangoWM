#!/usr/bin/env bash
set -euo pipefail

VENDOR_CERTS="${1:-microsoft}"
EFIVARS=/sys/firmware/efi/efivars
SBCTL_DIR=/var/lib/sbctl

log() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	cat <<EOF
Usage: $(basename "$0") [vendor-certs]

Create sbctl keys, sign EFI binaries, and enroll Secure Boot keys.
Default vendor cert set: ${VENDOR_CERTS}
EOF
	exit 0
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	exec sudo -- bash "$0" "$@"
fi

command -v sbctl >/dev/null 2>&1 || die "sbctl is not installed (pacman -S sbctl)"
[[ -d $EFIVARS ]] || die "System is not booted in UEFI mode"

var_data() {
	local f
	f=$(find "$EFIVARS" -maxdepth 1 -name "$1-*" -print -quit 2>/dev/null)
	[[ -n ${f:-} ]] || return 1
	od -An -tu1 "$f" | tr -dc '0-9'
}

setup_mode_active() {
	local d
	d=$(var_data SetupMode) || return 1
	[[ $d == *1 ]]
}

secure_boot_enabled() {
	local d
	d=$(var_data SecureBoot) || return 1
	[[ $d == *1 ]]
}

clear_immutable_flags() {
	local name f
	for name in PK KEK db dbx MokList MokListX; do
		f=$(find "$EFIVARS" -maxdepth 1 -name "${name}-*" -print -quit 2>/dev/null)
		if [[ -n ${f:-} ]] && lsattr -d "$f" 2>/dev/null | grep -q -- 'i'; then
			warn "Removing immutable flag from $f"
			chattr -i "$f"
		fi
	done
}

detect_esp() {
	local m
	while read -r m; do
		case $m in
		/boot | /efi | /boot/efi)
			printf '%s\n' "$m"
			return 0
			;;
		esac
	done < <(findmnt -rnno TARGET -t vfat)
	return 1
}

main() {
	local esp
	esp=$(detect_esp) || die "No ESP mounted at /boot, /efi or /boot/efi"
	log "ESP: $esp"

	if [[ ! -f $SBCTL_DIR/GUID ]]; then
		log "Creating secure boot keys"
		sbctl create-keys
	else
		log "Keys already exist in $SBCTL_DIR"
	fi

	local images=() img
	mapfile -t images < <(find "$esp" -type f \( -iname '*.efi' -o -name 'vmlinuz-*' \))
	((${#images[@]} > 0)) || die "No EFI binaries or kernels found on $esp"

	for img in "${images[@]}"; do
		if grep -qF "\"$img\"" "$SBCTL_DIR/files.json" 2>/dev/null; then
			log "Already signed: $img"
		else
			log "Signing: $img"
			sbctl sign -s "$img" || warn "Failed to sign $img"
		fi
	done

	if secure_boot_enabled; then
		log "Secure Boot is already enabled, nothing left to do"
	elif setup_mode_active; then
		clear_immutable_flags
		log "Enrolling keys into firmware (vendor certs: $VENDOR_CERTS)"
		local enroll_args=()
		[[ -n $VENDOR_CERTS ]] && enroll_args+=("--$VENDOR_CERTS")
		sbctl enroll-keys "${enroll_args[@]}"
		echo
		sbctl status
		echo
		log "Done. Reboot into firmware setup and enable Secure Boot:"
		log "  systemctl reboot --firmware-setup"
	else
		die "Firmware is not in Setup Mode. Clear/reset Secure Boot keys in your BIOS first, then re-run this script."
	fi
}

main
