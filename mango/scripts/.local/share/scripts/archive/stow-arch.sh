#!/bin/bash
# Preserved for reference; the NixOS stow.sh wrapper now applies the flake.
set -euo pipefail

# --- Configuration ---
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TARGET_DIR="${HOME}"
BACKUP_DIR="${DOTFILES_DIR}/.stow-backups/$(date +%Y%m%d-%H%M%S)"

# --- Helpers ---
log() { echo -e "\033[1;32m[+]\033[0m $1"; }
warn() { echo -e "\033[1;33m[!]\033[0m $1"; }
error() { echo -e "\033[1;31m[X]\033[0m $1"; exit 1; }

# --- Tasks ---
check_stow() {
    if ! command -v stow >/dev/null 2>&1; then
        log "Installing stow..."
        sudo pacman -S --needed --noconfirm stow
    fi
}

discover_packages() {
    local pkg
    local -a packages=()

    while IFS= read -r -d '' pkg; do
        pkg="${pkg#${DOTFILES_DIR}/}"

        case "$pkg" in
            .git|.stow-backups)
                continue
                ;;
        esac

        packages+=("$pkg")
    done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [ "${#packages[@]}" -eq 0 ]; then
        error "No stow packages found in $DOTFILES_DIR"
    fi

    printf '%s\n' "${packages[@]}"
}

has_stowable_files() {
    local pkg="$1"
    find "$DOTFILES_DIR/$pkg" \( -type f -o -type l \) -print -quit | grep -q .
}

list_absolute_source_symlinks() {
    local pkg="$1"
    while IFS= read -r -d '' source_link; do
        if [[ "$(readlink "$source_link")" = /* ]]; then
            printf '%s\0' "$source_link"
        fi
    done < <(find "$DOTFILES_DIR/$pkg" -type l -print0)
}

path_resolves_inside_dotfiles() {
    local path="$1"
    local resolved

    resolved="$(realpath -m "$path")"
    [[ "$resolved" == "$DOTFILES_DIR" || "$resolved" == "$DOTFILES_DIR"/* ]]
}

backup_conflicts() {
    local pkg="$1"
    local moved_any=0

    while IFS= read -r -d '' source_path; do
        local rel_path="${source_path#${DOTFILES_DIR}/${pkg}/}"
        local target_path="${TARGET_DIR}/${rel_path}"
        local backup_path="${BACKUP_DIR}/${rel_path}"

        if ([ -e "$target_path" ] || [ -L "$target_path" ]) && path_resolves_inside_dotfiles "$target_path"; then
            warn "Skipping $target_path: it already resolves inside $DOTFILES_DIR"
            continue
        fi

        if [ -e "$target_path" ] || [ -L "$target_path" ]; then
            mkdir -p "$(dirname "$backup_path")"
            mv "$target_path" "$backup_path"
            warn "Moved existing $target_path to $backup_path"
            moved_any=1
        fi
    done < <(find "$DOTFILES_DIR/$pkg" \( -type f -o -type l \) -print0)

    if [ "$moved_any" -eq 1 ]; then
        log "Backed up conflicting files for $pkg"
    fi
}

run_stow() {
    local -a stow_packages=()

    mapfile -t stow_packages < <(discover_packages)

    log "Linking configurations into $TARGET_DIR with stow..."
    log "Discovered packages: ${stow_packages[*]}"

    for pkg in "${stow_packages[@]}"; do
        local -a absolute_links=()
        local -a ignore_parts=()
        local ignore_regex='^$'

        if ! has_stowable_files "$pkg"; then
            warn "Skipping $pkg: no files to stow"
            continue
        fi

        while IFS= read -r -d '' source_link; do
            absolute_links+=("$source_link")
            ignore_parts+=("${source_link##*/}")
        done < <(list_absolute_source_symlinks "$pkg")

        if [ "${#absolute_links[@]}" -gt 0 ]; then
            warn "Package $pkg contains absolute symlink sources; they will be linked manually"
            ignore_regex="/($(printf '%s|' "${ignore_parts[@]}" | sed 's/|$//; s/\./\\./g'))$"
        fi

        log "Stowing $pkg..."
        backup_conflicts "$pkg"
        stow -R --ignore="$ignore_regex" -d "$DOTFILES_DIR" -t "$TARGET_DIR" "$pkg"

        if [ "${#absolute_links[@]}" -gt 0 ]; then
            local source_link
            for source_link in "${absolute_links[@]}"; do
                local rel_path="${source_link#${DOTFILES_DIR}/${pkg}/}"
                local target_path="${TARGET_DIR}/${rel_path}"
                local backup_path="${BACKUP_DIR}/${rel_path}"
                local link_target
                link_target="$(readlink "$source_link")"

                if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$link_target" ]; then
                    continue
                fi

                if ([ -e "$target_path" ] || [ -L "$target_path" ]) && path_resolves_inside_dotfiles "$target_path"; then
                    warn "Skipping $target_path: it already resolves inside $DOTFILES_DIR"
                    continue
                fi

                if [ -e "$target_path" ] || [ -L "$target_path" ]; then
                    mkdir -p "$(dirname "$backup_path")"
                    mv "$target_path" "$backup_path"
                    warn "Moved existing $target_path to $backup_path"
                fi

                mkdir -p "$(dirname "$target_path")"
                ln -s "$link_target" "$target_path"
                log "Linked absolute symlink $target_path -> $link_target"
            done
        fi
    done

    if [ -d "$BACKUP_DIR" ]; then
        log "Existing files were backed up to $BACKUP_DIR"
    fi
}

# --- Stow ---
check_stow
run_stow
