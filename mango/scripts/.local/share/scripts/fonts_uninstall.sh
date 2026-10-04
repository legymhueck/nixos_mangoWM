#!/usr/bin/env bash
set -euo pipefail

packages=(
    otf-aurulent-nerd
    otf-codenewroman-nerd
    otf-comicshanns-nerd
    otf-droid-nerd
    otf-fira-mono
    otf-fira-sans
    otf-firamono-nerd
    otf-font-awesome
    otf-hasklig-nerd
    otf-hermit-nerd
    otf-opendyslexic-nerd
    otf-overpass
    otf-overpass-nerd
    ttf-3270-nerd
    ttf-agave-nerd
    ttf-anonymouspro-nerd
    ttf-arimo-nerd
    ttf-bigblueterminal-nerd
    ttf-bitstream-vera-mono-nerd
    ttf-cascadia-code-nerd
    ttf-cousine-nerd
    ttf-daddytime-mono-nerd
    ttf-dejavu-nerd
    ttf-fantasque-nerd
    ttf-firacode-nerd
    ttf-go-nerd
    ttf-hack-nerd
    ttf-heavydata-nerd
    ttf-iawriter-nerd
    ttf-ibmplex-mono-nerd
    ttf-inconsolata-go-nerd
    ttf-inconsolata-lgc-nerd
    ttf-inconsolata-nerd
    ttf-iosevka-nerd
    ttf-iosevkaterm-nerd
    ttf-jetbrains-mono-nerd
    ttf-lekton-nerd
    ttf-liberation-mono-nerd
    ttf-lilex-nerd
    ttf-meslo-nerd
    ttf-monofur-nerd
    ttf-monoid-nerd
    ttf-mononoki-nerd
    ttf-mplus-nerd
    ttf-noto-nerd
    ttf-profont-nerd
    ttf-proggyclean-nerd
    ttf-roboto-mono-nerd
    ttf-sharetech-mono-nerd
    ttf-sourcecodepro-nerd
    ttf-space-mono-nerd
    ttf-terminus-nerd
    ttf-tinos-nerd
    ttf-ubuntu-mono-nerd
    ttf-ubuntu-nerd
    ttf-victor-mono-nerd
    awesome-terminal-fonts
    ttf-bitstream-vera
    ttf-caladea
    ttf-carlito
    ttf-dejavu
    ttf-droid
    ttf-fantasque-sans-mono
    ttf-fira-code
    ttf-fira-mono
    ttf-fira-sans
    ttf-font-awesome
    ttf-hack
    ttf-inconsolata
    ttf-jetbrains-mono
    ttf-joypixels
    ttf-liberation
    ttf-linux-libertine
    ttf-opensans
    ttf-roboto
    ttf-roboto-mono
    ttf-ubuntu-font-family
    adobe-source-sans-fonts
    noto-fonts
    noto-fonts-extra
    noto-fonts-cjk
    noto-fonts-emoji
    tex-gyre-fonts
    woff-fira-code
    woff2-fira-code
)

ASSUME_YES=0
if [[ "${1:-}" == "--yes" ]]; then
    ASSUME_YES=1
elif [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: sudo $(basename "$0") [--yes]"
    echo "Remove a large set of font packages with pacman -Rns."
    exit 0
fi

command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found." >&2; exit 1; }

if (( ASSUME_YES != 1 )); then
    echo "About to remove ${#packages[@]} font packages."
    read -r -p "Proceed? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 1; }
fi

sudo pacman -Rns --noconfirm "${packages[@]}"
echo "Font package removal complete."
