#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0")

Install Intel VA-API packages and write browser settings for hardware video decode.
EOF
    exit 0
fi

echo "=== Intel iGPU YouTube Hardware Acceleration Setup ==="

command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found." >&2; exit 1; }

# Install Intel VA-API drivers
echo "[1/5] Installing Intel VA-API drivers..."
sudo pacman -S --needed --noconfirm libva-intel-driver intel-media-driver libva-utils

# Verify VA-API
echo "[2/5] Verifying VA-API..."
if command -v vainfo >/dev/null 2>&1 && vainfo 2>/dev/null | grep -q "VAProfile"; then
    echo "VA-API working. Supported codecs:"
    vainfo 2>/dev/null | grep "VAProfile" | awk '{print $2}'
else
    echo "WARNING: vainfo failed or is unavailable. Reboot may be needed."
fi

# Configure Firefox
echo "[3/5] Configuring Firefox..."
firefox_prefs=("$HOME"/.mozilla/firefox/*.default-release/prefs.js "$HOME"/.mozilla/firefox/*.default/prefs.js)
if (( ${#firefox_prefs[@]} > 0 )); then
    for f in "${firefox_prefs[@]}"; do
        sed -i '/media.ffmpeg.vaapi.enabled/d' "$f"
        sed -i '/media.hardware-video-decoding.force-enabled/d' "$f"
        printf '%s\n' 'user_pref("media.ffmpeg.vaapi.enabled", true);' >> "$f"
        printf '%s\n' 'user_pref("media.hardware-video-decoding.force-enabled", true);' >> "$f"
    done
    echo "Firefox configured."
else
    echo "Firefox profile not found. Configure manually in about:config:"
    echo "  media.ffmpeg.vaapi.enabled = true"
    echo "  media.hardware-video-decoding.force-enabled = true"
fi

# Configure Chromium
echo "[4/5] Configuring Chromium..."
CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
CHROME_FLAGS="$HOME/.config/chrome-flags.conf"

FLAGS_CONTENT="--enable-features=AcceleratedVideoDecodeLinuxGL
--ignore-gpu-blocklist
--enable-gpu-rasterization
--enable-zero-copy"

for flagfile in "$CHROMIUM_FLAGS" "$CHROME_FLAGS"; do
    mkdir -p "$(dirname "$flagfile")"
    printf '%s\n' "$FLAGS_CONTENT" > "$flagfile"
    echo "Written: $flagfile"
done

# Test with mpv (if installed)
echo "[5/5] Testing..."
if command -v mpv >/dev/null 2>&1; then
    echo "To test with mpv:"
    echo "  mpv --hwdec=vaapi https://www.youtube.com/watch?v=dQw4w9WgXcQ"
else
    echo "mpv not installed. Install with: sudo pacman -S mpv"
fi

echo
echo "=== Setup Complete ==="
echo "Play a YouTube video and run 'intel_gpu_top' (as root) to verify GPU usage."
echo "Install intel-gpu-tools: sudo pacman -S intel-gpu-tools"
