#!/usr/bin/env bash
# Source this script so the ssh-agent environment persists in the current shell.

_git_authenticate_main() {
    local key_path="${1:-$HOME/.ssh/miclehGitHub}"

    if ! command -v ssh-agent >/dev/null 2>&1; then
        echo "Error: ssh-agent is not installed." >&2
        return 1
    fi

    if ! command -v ssh-add >/dev/null 2>&1; then
        echo "Error: ssh-add is not installed." >&2
        return 1
    fi

    if [[ ! -f "$key_path" ]]; then
        echo "Error: SSH key not found: $key_path" >&2
        return 1
    fi

    if ! ssh-add -l >/dev/null 2>&1; then
        eval "$(ssh-agent -s)" >/dev/null
    fi

    ssh-add "$key_path"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Error: source this script instead of executing it." >&2
    echo "Usage: . \"$0\" [path-to-private-key]" >&2
    exit 1
fi

_git_authenticate_main "$@"
unset -f _git_authenticate_main