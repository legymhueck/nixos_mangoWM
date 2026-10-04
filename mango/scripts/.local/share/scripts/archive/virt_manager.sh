#!/usr/bin/env bash

# Strict mode for better error handling
set -euo pipefail

# Color and formatting output functions
_info() {
    echo -e "\e[34m[INFO]\e[0m $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

_error() {
    echo -e "\e[31m[ERROR]\e[0m $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $(basename "$0")

Install and configure libvirt, QEMU, and related virtualization services on Arch.
EOF
    exit 0
fi

VIRTUALIZATION_PACKAGES=(
    # Virtualization core
    "qemu-full"
    "libvirt"
    "virt-manager"
    "virt-install"
    "virt-viewer"
    
    # Network and system utilities
    "dmidecode"
    "dnsmasq"
    
    # Security and management
    "edk2-ovmf"
    "libguestfs"
    "screen"
    "swtpm"
)

# Validate system requirements
validate_system() {
    # Check if running on Arch Linux or derivatives
    if [[ ! -f /etc/arch-release ]]; then
        _error "This script is designed for Arch Linux and its derivatives."
        exit 1
    fi

    # Check for sudo/root access
    if [[ $EUID -eq 0 ]]; then
        _error "Do not run this script as root or with sudo privileges."
        exit 1
    fi
}

# Update system packages
update_system() {
    _info "Updating system packages..."
    sudo pacman -Syu --noconfirm || {
        _error "Failed to update system packages"
        exit 1
    }
}

# Install virtualization packages
install_virtualization_packages() {
    _info "Installing virtualization components..."
    local packages_string=$(IFS=" "; echo "${VIRTUALIZATION_PACKAGES[*]}")
    
    sudo pacman -S --needed --noconfirm $packages_string || {
        _error "Failed to install virtualization packages"
        exit 1
    }
}

# Configure libvirt access group
configure_libvirt_groups() {
    local user_name=$(whoami)
    _info "Configuring libvirt group access..."

    if ! getent group libvirt &> /dev/null; then
        _error "Group 'libvirt' does not exist after installing libvirt."
        exit 1
    fi

    if ! id -nG "$user_name" | grep -qw libvirt; then
        sudo usermod -aG libvirt "$user_name" || {
            _error "Failed to add user to libvirt group"
            exit 1
        }
        _info "Added $user_name to libvirt group"
    fi
}

# Optional legacy file-permission auth mode.
# NOTE: On modern systemd socket activation setups, socket permission settings are
# usually controlled by unit files rather than libvirtd.conf. Keep this disabled by
# default unless you explicitly need file-based auth behavior.
configure_libvirt_legacy_file_permissions_mode() {
    if [[ "${LIBVIRT_USE_FILE_PERMS:-0}" != "1" ]]; then
        _info "Skipping legacy libvirtd.conf permission mode (set LIBVIRT_USE_FILE_PERMS=1 to enable)."
        return
    fi

    _info "Applying legacy file-permission auth mode in libvirtd.conf..."
    if [[ ! -f /etc/libvirt/libvirtd.conf ]]; then
        _error "/etc/libvirt/libvirtd.conf not found. Cannot apply legacy mode."
        exit 1
    fi

    sudo sed -i \
        -e 's/^#\?unix_sock_group = .*/unix_sock_group = "libvirt"/' \
        -e 's/^#\?unix_sock_rw_perms = .*/unix_sock_rw_perms = "0770"/' \
        /etc/libvirt/libvirtd.conf || {
        _error "Failed to modify libvirtd.conf"
        exit 1
    }
}

# Start and enable libvirt services
configure_libvirt_services() {
    _info "Configuring modular libvirt services (socket-first)..."
    # Check for systemctl
    if ! command -v systemctl &> /dev/null; then
        _error "systemctl command not found. Cannot manage services."
        exit 1
    fi

    local has_modular_units=0
    if systemctl list-unit-files --type=socket | grep -q '^virtqemud\.socket'; then
        has_modular_units=1
    fi

    if [[ $has_modular_units -eq 1 ]]; then
        # Preferred on modern systems: modular daemon socket activation.
        sudo systemctl enable --now virtqemud.socket || {
            _error "Failed to enable/start virtqemud.socket"
            exit 1
        }

        sudo systemctl enable --now virtnetworkd.socket || {
            _error "Failed to enable/start virtnetworkd.socket"
            exit 1
        }

        sudo systemctl enable --now virtstoraged.socket || {
            _error "Failed to enable/start virtstoraged.socket"
            exit 1
        }
    else
        _info "Modular libvirt sockets not found; falling back to libvirtd.socket."
        sudo systemctl enable --now libvirtd.socket || {
            _error "Failed to enable/start libvirtd.socket"
            exit 1
        }
    fi

    # Keep logging daemon available in socket mode.
    sudo systemctl enable --now virtlogd.socket || {
        _error "Failed to enable/start virtlogd.socket"
        exit 1
    }

    # If you rely on VM/domain autostart at host boot, enable service mode too.
    if [[ "${LIBVIRT_ENABLE_SERVICE_AUTOSTART:-0}" == "1" ]]; then
        if [[ $has_modular_units -eq 1 ]]; then
            _info "Enabling modular libvirt services for domain autostart support..."
            sudo systemctl enable --now virtqemud.service virtnetworkd.service virtstoraged.service || {
                _error "Failed to enable/start modular libvirt services"
                exit 1
            }
        else
            _info "Enabling libvirtd.service for domain autostart support..."
            sudo systemctl enable --now libvirtd.service || {
                _error "Failed to enable/start libvirtd.service"
                exit 1
            }
        fi
    fi

    # Start default network
    if command -v virsh &> /dev/null; then
        sudo virsh -c qemu:///system net-autostart default || true
        sudo virsh -c qemu:///system net-start default || true
    else
        _error "virsh command not found. Skipping network autostart."
    fi
}

# Configure firewalld
configure_firewall_firewalld() {
    _info "Configuring firewall (firewalld)..."
    # Check for firewall-cmd
    if ! command -v firewall-cmd &> /dev/null; then
        _info "firewalld not found. Installing firewalld..."
        sudo pacman -S --noconfirm firewalld
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
    fi
    # libvirt integrates with firewalld and manages the libvirt zone on modern setups.
    sudo firewall-cmd --reload || {
        _error "Failed to configure firewall"
        exit 1
    }
}

# Configure forwarding for UFW/libvirt NAT networking.
configure_ufw_forwarding() {
    local sysctl_conf="/etc/ufw/sysctl.conf"

    if [[ ! -f "$sysctl_conf" ]]; then
        _error "$sysctl_conf not found. Cannot configure forwarding."
        exit 1
    fi

    sudo sed -i \
        -e 's/^#\s*net\/ipv4\/ip_forward=1/net\/ipv4\/ip_forward=1/' \
        -e 's/^#\s*net\/ipv6\/conf\/default\/forwarding=1/net\/ipv6\/conf\/default\/forwarding=1/' \
        -e 's/^#\s*net\/ipv6\/conf\/all\/forwarding=1/net\/ipv6\/conf\/all\/forwarding=1/' \
        "$sysctl_conf" || {
        _error "Failed to update UFW forwarding settings"
        exit 1
    }
}

# Configure ufw
configure_firewall_ufw() {
    _info "Configuring firewall (ufw)..."
    # Check for ufw
    if ! command -v ufw &> /dev/null; then
        _info "ufw not found. Installing ufw..."
        sudo pacman -S --noconfirm ufw
    fi

    # Ensure ufw service is enabled
    sudo systemctl enable ufw
    sudo systemctl start ufw

    # Allow libvirt's default bridge traffic (DNS + DHCP) on virbr0
    sudo ufw allow in on virbr0 to any port 53 proto tcp
    sudo ufw allow in on virbr0 to any port 53 proto udp
    sudo ufw allow in on virbr0 to any port 67 proto udp

    # Allow forwarding from libvirt guests to external networks
    sudo ufw route allow in on virbr0 out on any
    sudo ufw route allow out on virbr0
    sudo ufw allow in on virbr0

    configure_ufw_forwarding

    sudo ufw reload || {
        _error "Failed to configure ufw"
        exit 1
    }
}

# Main execution function
main() {
    validate_system
    update_system
    install_virtualization_packages
    configure_libvirt_groups
    configure_libvirt_legacy_file_permissions_mode
    configure_libvirt_services
    # Choose one firewall backend by commenting/uncommenting the lines below.
    # configure_firewall_firewalld
    configure_firewall_ufw
    
    _success "Virtualization setup completed successfully!"
    _info "Please log out and log back in for group changes to take effect."
}

# Execute main function
main
