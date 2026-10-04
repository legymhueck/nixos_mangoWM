#!/usr/bin/env bash
#
# gsmartcontrol-wayland-fix.sh
#
# Fixes GSmartControl not opening under Wayland compositors (niri, sway, etc.)
# after entering the polkit password.
#
# Root cause: gsmartcontrol_polkit elevates via `pkexec`, which strips the
# WAYLAND_DISPLAY/XDG_RUNTIME_DIR variables. The root instance falls back to the
# X11 display (:0), which the compositor's Xwayland restricts to the local user
# (SI:localuser:USER), so root is denied: "Authorization required, but no
# authorization protocol specified" -> the GUI never appears.
#
# The fix relaunches GSmartControl as root reattached to the caller's Wayland
# session, via a wrapper + a dedicated polkit action + a pacman hook so the
# launcher patch survives gsmartcontrol upgrades.
#
# Usage:
#   sudo ./gsmartcontrol-wayland-fix.sh        # apply the fix
#   sudo ./gsmartcontrol-wayland-fix.sh --dry-run
#
# Idempotent: safe to re-run.

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

say()   { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m    OK: %s\033[0m\n' "$*"; }
die()   { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '    (dry-run) %s\n' "$*"
        return 0
    fi
    "$@"
}

[[ "$(id -u)" -eq 0 ]] || die "run with sudo"
command -v pacman >/dev/null || die "pacman not found (this script targets Arch-based systems)"

# ---------------------------------------------------------------- prerequisites
pacman -Q gsmartcontrol >/dev/null 2>&1 || die "gsmartcontrol is not installed"
pkexec --version >/dev/null 2>&1 || die "polkit (pkexec) not found"
command -v gsmartcontrol >/dev/null || die "/usr/bin/gsmartcontrol not found"

say "Detecting display session..."
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    ok "Wayland session detected (WAYLAND_DISPLAY=${WAYLAND_DISPLAY})"
else
    say "WARNING: WAYLAND_DISPLAY is not set in this shell."
    say "         The fix only matters on a Wayland session; continuing anyway."
fi

WRAPPER="/usr/local/bin/gsmartcontrol-root"
POLICY="/usr/share/polkit-1/actions/org.local.gsmartcontrol.policy"
LAUNCHER="/usr/bin/gsmartcontrol_polkit"
HOOK="/etc/pacman.d/hooks/gsmartcontrol-wayland.hook"
FIXBIN="/usr/local/bin/gsmartcontrol-fix"

# ---------------------------------------------------------------- wrapper
say "Installing wrapper $WRAPPER"
cat > /tmp/gsmartcontrol-root.tmp <<'EOF'
#!/bin/bash
# Run GSmartControl as root, reattached to the invoking user's Wayland session.
# pkexec strips the GUI environment, so restore what is needed to show the window.

if [ -n "$PKEXEC_UID" ]; then
    RUNTIME="/run/user/$PKEXEC_UID"
    if [ -f "$RUNTIME/gsmartcontrol.env" ]; then
        while IFS='=' read -r k v; do
            [ -n "$k" ] && export "$k=$v"
        done < "$RUNTIME/gsmartcontrol.env"
    fi
    if [ -z "$WAYLAND_DISPLAY" ]; then
        for s in "$RUNTIME"/wayland-*; do
            if [ -S "$s" ]; then
                export WAYLAND_DISPLAY="$(basename "$s")"
                break
            fi
        done
    fi
    [ -n "$XDG_RUNTIME_DIR" ] || export XDG_RUNTIME_DIR="$RUNTIME"
fi

exec /usr/bin/gsmartcontrol "$@"
EOF
run install -m 755 /tmp/gsmartcontrol-root.tmp "$WRAPPER" && ok "wrapper installed"

# ---------------------------------------------------------------- polkit action
say "Installing polkit action $POLICY"
cat > /tmp/org.local.gsmartcontrol.tmp <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.local.gsmartcontrol">
    <message>Authentication is required to run GSmartControl</message>
    <icon_name>gsmartcontrol</icon_name>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/gsmartcontrol-root</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
EOF
run install -m 644 /tmp/org.local.gsmartcontrol.tmp "$POLICY" && ok "polkit action installed"

# ---------------------------------------------------------------- launcher patch
say "Patching launcher $LAUNCHER"
cat > /tmp/gsmartcontrol_polkit.tmp <<'EOF'
#!/bin/bash
if command -v pkexec >/dev/null 2>&1; then
	ENVFILE=""
	if [ -n "$XDG_RUNTIME_DIR" ] && [ -d "$XDG_RUNTIME_DIR" ] && [ -n "$WAYLAND_DISPLAY" ]; then
		ENVFILE="$XDG_RUNTIME_DIR/gsmartcontrol.env"
		printf 'WAYLAND_DISPLAY=%s\nXDG_RUNTIME_DIR=%s\n' "$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR" > "$ENVFILE"
		chmod 600 "$ENVFILE"
	fi
	pkexec --disable-internal-agent "/usr/local/bin/gsmartcontrol-root" "$@"
	RET=$?
	[ -n "$ENVFILE" ] && rm -f "$ENVFILE"
	exit $RET
else
	/usr/bin/gsmartcontrol "$@"
fi
EOF
run install -m 755 /tmp/gsmartcontrol_polkit.tmp "$LAUNCHER" && ok "launcher patched"

# ---------------------------------------------------------------- pacman hook
say "Installing pacman hook $HOOK"
cat > /tmp/gsmartcontrol-fix.tmp <<'PATCHEOF'
#!/bin/bash
# Reapply the Wayland fix for /usr/bin/gsmartcontrol_polkit after gsmartcontrol upgrades.
WRAPPER="/usr/local/bin/gsmartcontrol-root"
TARGET="/usr/bin/gsmartcontrol_polkit"
if [ ! -x "$WRAPPER" ] || [ ! -f "$TARGET" ]; then
    exit 0
fi
if grep -q "gsmartcontrol-root" "$TARGET"; then
    exit 0
fi
TMP="$(mktemp)"
cat > "$TMP" <<'PATCH'
#!/bin/bash
if command -v pkexec >/dev/null 2>&1; then
	ENVFILE=""
	if [ -n "$XDG_RUNTIME_DIR" ] && [ -d "$XDG_RUNTIME_DIR" ] && [ -n "$WAYLAND_DISPLAY" ]; then
		ENVFILE="$XDG_RUNTIME_DIR/gsmartcontrol.env"
		printf 'WAYLAND_DISPLAY=%s\nXDG_RUNTIME_DIR=%s\n' "$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR" > "$ENVFILE"
		chmod 600 "$ENVFILE"
	fi
	pkexec --disable-internal-agent "/usr/local/bin/gsmartcontrol-root" "$@"
	RET=$?
	[ -n "$ENVFILE" ] && rm -f "$ENVFILE"
	exit $RET
else
	/usr/bin/gsmartcontrol "$@"
fi
PATCH
chmod 755 "$TMP"
install -m 755 "$TMP" "$TARGET"
rm -f "$TMP"
exit 0
PATCHEOF
run install -m 755 /tmp/gsmartcontrol-fix.tmp "$FIXBIN"
cat > /tmp/gsmartcontrol-wayland.hook.tmp <<'HOOKEOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = gsmartcontrol

[Action]
Description = Reapplying GSmartControl Wayland display fix...
When = PostTransaction
Exec = /usr/local/bin/gsmartcontrol-fix
HOOKEOF
run install -m 644 /tmp/gsmartcontrol-wayland.hook.tmp "$HOOK" && ok "pacman hook installed"

# ---------------------------------------------------------------- verification
say "Verifying..."
if [[ "$DRY_RUN" -eq 1 ]]; then
    say "Dry run complete. Re-run without --dry-run to apply."
    exit 0
fi

rm -f /tmp/gsmartcontrol*.tmp /tmp/org.local.gsmartcontrol.tmp

pkaction | grep -q "^org.local.gsmartcontrol$" && ok "polkit action registered" \
    || die "polkit action not visible to pkaction"
grep -q "gsmartcontrol-root" "$LAUNCHER" && ok "launcher references wrapper" \
    || die "launcher patch missing"
[[ -x "$WRAPPER" ]] && ok "$WRAPPER executable"
[[ -f "$HOOK" ]] && ok "$HOOK present"
ok "done. Launch GSmartControl; enter your password and the window should open."
