#!/bin/bash
#
# setup-env.sh - Environment setup script for BananaWRT CI/CD
#
# Usage: setup-env.sh [setup|clean] [options]
#
# Options:
#   -v, --verbose    Show detailed output
#   -d, --dry-run    Show what would be done without doing it
#   -h, --help       Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANANAWRT_ROOT="${BANANAWRT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Source libraries
source "${BANANAWRT_ROOT}/lib/common.sh"
source "${BANANAWRT_ROOT}/lib/logging.sh"

# Configuration
declare -A PACKAGE_MAPPING=(
    ["gnutls-dev"]="libgnutls28-dev"
    ["libz-dev"]="zlib1g-dev"
    ["mkisofs"]="genisoimage"
    ["libbabeltrace-ctf-dev"]="libbabeltrace-dev"
)

# Common packages for all architectures
COMMON_PACKAGES=(
    ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk
    gettext git libgnutls28-dev gperf haveged help2man intltool libelf-dev
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev
    libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev zlib1g-dev lld
    llvm lrzsz genisoimage nano ninja-build p7zip p7zip-full patch pkgconf python3
    python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c
    rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim
    wget xmlto xxd zlib1g-dev zstd gh git jq
)

# Architecture-specific packages
X86_64_PACKAGES=(gcc-multilib g++-multilib libc6-dev-i386 lib32gcc-s1)
AARCH64_PACKAGES=(libc6-dev libdw-dev zlib1g-dev liblzma-dev libelf-dev libpfm4 libpfm4-dev libbabeltrace-dev libtool-bin)

# Parse arguments
ACTION=""
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        setup|clean)
            ACTION="$1"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $(get_script_name) [setup|clean] [options]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed output"
            echo "  -d, --dry-run    Show what would be done without doing it"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit $EXIT_INVALID_ARGS
            ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    log_error "Usage: $(get_script_name) [setup|clean] [options]"
    exit $EXIT_INVALID_ARGS
fi

export DEBIAN_FRONTEND=noninteractive

# Get the actual package name (handle aliases)
get_actual_package_name() {
    local package="$1"
    echo "${PACKAGE_MAPPING[$package]:-$package}"
}

# Check if a package is installed
is_package_installed() {
    local package="$1"
    local actual_package
    actual_package=$(get_actual_package_name "$package")

    # Check with dpkg
    if dpkg -l "$actual_package" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi

    # Check if the requested name is different from actual
    if [[ "$package" != "$actual_package" ]]; then
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            return 0
        fi
    fi

    # Check for virtual packages
    if apt-cache show "$package" &>/dev/null; then
        local providing_packages
        providing_packages=$(apt-cache showpkg "$package" 2>/dev/null | \
            awk '/^Reverse Provides:/{flag=1;next} /^[A-Za-z]/{flag=0} flag{print $1}')

        for providing_pkg in $providing_packages; do
            if dpkg -l "$providing_pkg" 2>/dev/null | grep -q "^ii"; then
                return 0
            fi
        done
    fi

    return 1
}

# Get packages that need action
get_packages_for_action() {
    local -n packages=$1
    local action="$2"
    local result=()

    for pkg in "${packages[@]}"; do
        if [[ "$action" == "setup" ]]; then
            if ! is_package_installed "$pkg"; then
                result+=("$pkg")
                [[ "$VERBOSE" == true ]] && log_info "Package $pkg needs to be installed"
            else
                [[ "$VERBOSE" == true ]] && log_info "Package $pkg is already installed"
            fi
        elif [[ "$action" == "clean" ]]; then
            if is_package_installed "$pkg"; then
                result+=("$pkg")
                [[ "$VERBOSE" == true ]] && log_info "Package $pkg will be removed"
            else
                [[ "$VERBOSE" == true ]] && log_info "Package $pkg is not installed"
            fi
        fi
    done

    echo "${result[@]}"
}

# Verify packages after action
verify_packages() {
    local packages="$1"
    local action="$2"
    local failed=()
    local success_count=0

    for pkg in $packages; do
        if [[ "$action" == "setup" ]]; then
            if is_package_installed "$pkg"; then
                ((success_count++))
                [[ "$VERBOSE" == true ]] && log_success "Verified: $pkg is installed"
            else
                failed+=("$pkg")
                [[ "$VERBOSE" == true ]] && log_error "Verification failed: $pkg is not installed"
            fi
        elif [[ "$action" == "clean" ]]; then
            if ! is_package_installed "$pkg"; then
                ((success_count++))
                [[ "$VERBOSE" == true ]] && log_success "Verified: $pkg is removed"
            else
                failed+=("$pkg")
                [[ "$VERBOSE" == true ]] && log_error "Verification failed: $pkg is still installed"
            fi
        fi
    done

    echo "$success_count|${failed[*]}"
}

# Manage packages in batch
manage_packages_batch() {
    local packages="$1"
    local action="$2"

    if [[ -z "$packages" ]]; then
        log_info "No packages need to be processed for action: $action"
        return 0
    fi

    local package_count
    package_count=$(echo "$packages" | wc -w)

    if [[ "$action" == "setup" ]]; then
        log_info "Installing $package_count packages"
        [[ "$VERBOSE" == true ]] && log_info "Packages: ${packages// /, }"

        if [[ "$DRY_RUN" == false ]]; then
            local apt_output exit_code
            if [[ "$VERBOSE" == true ]]; then
                sudo apt install -y $packages
            else
                apt_output=$(sudo apt -qq install -y $packages 2>&1)
            fi
            exit_code=$?

            # Verify installation
            local verification
            verification=$(verify_packages "$packages" "setup")
            local success_count=${verification%%|*}
            local failed_packages=${verification#*|}

            if [[ -z "${failed_packages// /}" ]]; then
                log_success "$success_count packages installed and verified"
            else
                log_error "Some packages failed to install: $failed_packages"
                [[ "$VERBOSE" == false ]] && log_info "APT output: $apt_output"

                # Retry failed packages individually
                log_info "Attempting individual installation of failed packages..."
                for pkg in $failed_packages; do
                    log_info "Installing $pkg individually..."
                    if sudo apt install -y "$pkg" && is_package_installed "$pkg"; then
                        log_success "Package $pkg installed"
                    else
                        log_error "Failed to install package $pkg"
                    fi
                done
            fi
        else
            log_info "[DRY RUN] Would install: $packages"
        fi

    elif [[ "$action" == "clean" ]]; then
        log_info "Removing $package_count packages"
        [[ "$VERBOSE" == true ]] && log_info "Packages: ${packages// /, }"

        if [[ "$DRY_RUN" == false ]]; then
            local apt_output
            if [[ "$VERBOSE" == true ]]; then
                sudo apt remove --purge -y $packages
            else
                apt_output=$(sudo apt -qq remove --purge -y $packages 2>&1)
            fi

            # Verify removal
            local verification
            verification=$(verify_packages "$packages" "clean")
            local success_count=${verification%%|*}
            local failed_packages=${verification#*|}

            if [[ -z "${failed_packages// /}" ]]; then
                log_success "$success_count packages removed and verified"
            else
                log_error "Some packages failed to remove: $failed_packages"
                [[ "$VERBOSE" == false ]] && log_info "APT output: $apt_output"
            fi
        else
            log_info "[DRY RUN] Would remove: $packages"
        fi
    fi
}

# Show package statistics
show_package_stats() {
    local packages="$1"
    local action="$2"
    local packages_to_process
    packages_to_process=$(get_packages_for_action packages "$action")

    local total_count action_count already_done
    total_count=$(echo "$packages" | wc -w)
    action_count=$(echo "$packages_to_process" | wc -w)
    already_done=$((total_count - action_count))

    if [[ "$action" == "setup" ]]; then
        log_info "Package status: $already_done already installed, $action_count to install, $total_count total"
    else
        log_info "Package status: $already_done not installed, $action_count to remove, $total_count total"
    fi
}

# Get packages for current architecture
get_arch_packages() {
    local arch
    arch=$(get_arch)

    case "$arch" in
        x86_64)
            echo "${X86_64_PACKAGES[*]}"
            ;;
        aarch64)
            echo "${AARCH64_PACKAGES[*]}"
            ;;
        *)
            log_error "Unknown architecture: $arch"
            exit $EXIT_FAILURE
            ;;
    esac
}

# Main execution
main() {
    log_info "Updating package list..."
    if [[ "$DRY_RUN" == false ]]; then
        sudo apt -qq update
    else
        log_info "[DRY RUN] Would update package list"
    fi

    local arch
    arch=$(get_arch)
    log_info "Detected architecture: $arch"

    # Convert arrays to space-separated strings
    local common_pkgs="${COMMON_PACKAGES[*]}"
    local arch_pkgs
    arch_pkgs=$(get_arch_packages)

    if [[ "$ACTION" == "setup" ]]; then
        # Upgrade system first
        log_info "Upgrading installed packages..."
        if [[ "$DRY_RUN" == false ]]; then
            if sudo apt -qq full-upgrade -y &>/dev/null; then
                log_success "System upgraded"
            else
                log_error "System upgrade failed"
            fi
        else
            log_info "[DRY RUN] Would upgrade system packages"
        fi

        # Install common packages
        log_section "Setting up common packages"
        show_package_stats "$common_pkgs" "setup"
        manage_packages_batch "$common_pkgs" "setup"

        # Install architecture-specific packages
        log_section "Setting up packages for $arch"
        show_package_stats "$arch_pkgs" "setup"
        manage_packages_batch "$arch_pkgs" "setup"

    elif [[ "$ACTION" == "clean" ]]; then
        # Remove common packages
        log_section "Cleaning up common packages"
        show_package_stats "$common_pkgs" "clean"
        manage_packages_batch "$common_pkgs" "clean"

        # Remove architecture-specific packages
        log_section "Cleaning up packages for $arch"
        show_package_stats "$arch_pkgs" "clean"
        manage_packages_batch "$arch_pkgs" "clean"
    fi

    # Final cleanup
    log_info "Final cleaning..."
    if [[ "$DRY_RUN" == false ]]; then
        if sudo apt -qq autoremove --purge -y &>/dev/null; then
            log_success "Unused packages removed"
        else
            log_error "Failed to remove unused packages"
        fi

        if sudo apt -qq clean &>/dev/null; then
            log_success "Package cache cleaned"
        else
            log_error "Failed to clean package cache"
        fi
    else
        log_info "[DRY RUN] Would remove unused packages and clean cache"
    fi

    log_success "Operation completed successfully!"
}

main "$@"
