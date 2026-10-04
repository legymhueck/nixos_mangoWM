#!/usr/bin/env bash
# Enable HDMI/DP digital audio on HP ProDesk 400 G5 Desktop Mini (and similar
# HP systems) running Linux.
#
# The HP BIOS marks the Intel Kabylake HDMI/DP audio codec (0x8086280b) pins
# as [N/A], so the kernel skips them and no digital audio device is created.
# This installs a codec pincfg override via the snd-hda-intel 'patch=' option.
#
# Usage: sudo ./install-hdmi-audio-fix.sh [--reload]
#   --reload  also try to reload the driver live (else reboot is required)
set -euo pipefail

CODEC_VENDOR_ID="0x8086280b"
FW="/lib/firmware/hda-intel-fix.fw"
CONF="/etc/modprobe.d/hda-intel-fix.conf"

if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root: sudo $0 [--reload]" >&2
    exit 1
fi

RELOAD=0
for arg in "$@"; do
    case "$arg" in
        --reload) RELOAD=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# Bail out unless this machine actually has the affected Intel HDMI codec.
if ! grep -qE "Intel (Kabylake|Kaby Lake) HDMI|Vendor Id: ${CODEC_VENDOR_ID}" \
        /proc/asound/card*/codec#* 2>/dev/null; then
    echo "No affected Intel HDMI codec (${CODEC_VENDOR_ID}) found; nothing to do." >&2
    exit 0
fi

# Patch firmware: force the three HDMI/DP pins from [N/A] to jack (connected),
# changing Port Connectivity bits [31:30] from 01 to 00.
cat > "${FW}" <<'EOF'
[codec]
0x8086280b 0x80860101 2

[pincfg]
0x05 0x18560010
0x06 0x18560020
0x07 0x18560030
EOF
chmod 0644 "${FW}"

cat > "${CONF}" <<'EOF'
# HP ProDesk 400 G5 Desktop Mini (PCI 0x103c:0x859c)
# BIOS marks Intel Kabylake HDMI/DP audio pins as [N/A], so the kernel
# skips them and no digital audio device is created. Override the pin
# configs (Port Connectivity -> jack) so the pins are registered.
options snd-hda-intel patch=hda-intel-fix.fw
EOF
chmod 0644 "${CONF}"

echo "Installed ${FW} and ${CONF}"

if [[ ${RELOAD} -eq 1 ]]; then
    # Only safe if nothing (PipeWire/PulseAudio) is holding the audio card.
    if modprobe -r snd_hda_intel 2>/dev/null; then
        modprobe snd_hda_intel
        echo "Driver reloaded."
    else
        echo "Could not unload snd_hda_intel (audio in use?). Reboot instead." >&2
        exit 1
    fi
else
    echo "Reboot for the patch to take effect."
fi

echo
echo "Verify after reboot with:"
echo "  cat /proc/asound/pcm     # expect 'HDMI 0', 'HDMI 1', 'HDMI 2'"
echo "  pactl list short sinks   # expect HDMI/DP sinks"
