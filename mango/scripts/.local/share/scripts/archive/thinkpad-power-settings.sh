#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-power-saver}"
PLATFORM_PROFILE="${PLATFORM_PROFILE:-low-power}"
MIN_PERF_PCT="${MIN_PERF_PCT:-10}"
MAX_PERF_PCT="${MAX_PERF_PCT:-70}"
NO_TURBO="${NO_TURBO:-1}"

usage() {
  cat <<EOF
Usage: sudo $(basename "$0")

Apply low-noise ThinkPad-oriented power settings.

Environment:
  PROFILE           power-profiles-daemon profile (default: power-saver)
  PLATFORM_PROFILE  ACPI platform profile (default: low-power)
  MIN_PERF_PCT      intel_pstate min_perf_pct (default: 10)
  MAX_PERF_PCT      intel_pstate max_perf_pct (default: 70)
  NO_TURBO          intel_pstate no_turbo (default: 1)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

log() {
  printf '[thinkpad-power] %s\n' "$*"
}

set_sysfs() {
  local path="$1"
  local value="$2"
  local label="$3"

  if [[ -e "$path" ]]; then
    printf '%s' "$value" > "$path"
    log "set ${label}=${value}"
  else
    log "skip ${label} (missing ${path})"
  fi
}

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
  systemctl enable --now power-profiles-daemon.service >/dev/null 2>&1 || true
fi

if command -v powerprofilesctl >/dev/null 2>&1; then
  if powerprofilesctl set "$PROFILE"; then
    log "set power profile=${PROFILE}"
  else
    log "failed to set power profile=${PROFILE}"
  fi
else
  log "skip power profile (powerprofilesctl not installed)"
fi

if [[ -f /sys/firmware/acpi/platform_profile_choices ]] && grep -qw "$PLATFORM_PROFILE" /sys/firmware/acpi/platform_profile_choices; then
  set_sysfs /sys/firmware/acpi/platform_profile "$PLATFORM_PROFILE" platform_profile
else
  log "skip platform_profile=${PLATFORM_PROFILE} (unsupported)"
fi

set_sysfs /sys/devices/system/cpu/intel_pstate/no_turbo "$NO_TURBO" no_turbo
set_sysfs /sys/devices/system/cpu/intel_pstate/min_perf_pct "$MIN_PERF_PCT" min_perf_pct
set_sysfs /sys/devices/system/cpu/intel_pstate/max_perf_pct "$MAX_PERF_PCT" max_perf_pct

if [[ -r /sys/module/thinkpad_acpi/parameters/fan_control ]]; then
  fan_control=$(< /sys/module/thinkpad_acpi/parameters/fan_control)
  log "firmware fan control remains ${fan_control}; no manual fan override applied"
fi

if command -v powerprofilesctl >/dev/null 2>&1; then
  current_profile=$(powerprofilesctl get 2>/dev/null || true)
  [[ -n "$current_profile" ]] && log "current power profile=${current_profile}"
fi

for path in \
  /sys/firmware/acpi/platform_profile \
  /sys/devices/system/cpu/intel_pstate/no_turbo \
  /sys/devices/system/cpu/intel_pstate/min_perf_pct \
  /sys/devices/system/cpu/intel_pstate/max_perf_pct \
  /proc/acpi/ibm/fan; do
  if [[ -r "$path" ]]; then
    log "state ${path}:"
    while IFS= read -r line; do
      log "  ${line}"
    done < "$path"
  fi
done
