#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec sudo nixos-rebuild switch --flake "$repo_dir#nixbox" "$@"
