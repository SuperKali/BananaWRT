#!/bin/bash
set -euo pipefail

source "$GITHUB_WORKSPACE/.github/scripts/functions/formatter.sh"

RELEASE_TYPE="${1:-stable}"
PATCH_BASE_DIR="$GITHUB_WORKSPACE/patch"
IMMORTALWRT_DIR="${2:-$PWD}"

apply_patches() {
    local patch_type="$1"
    local source_dir="$2"  
    local dest_dir="$3"
    local description="$4"
    
    local patch_dir="$PATCH_BASE_DIR/$patch_type/$RELEASE_TYPE"
    
    if [ ! -d "$patch_dir" ]; then
        info "No $patch_type patches found for $RELEASE_TYPE release type - skipping"
        return 0
    fi
    
    local file_count=$(find "$patch_dir" -type f | wc -l)
    if [ "$file_count" -eq 0 ]; then
        info "No files found in $patch_type patches directory - skipping"
        return 0
    fi
    
    section "Applying $description ($file_count files)"
    
    if [ ! -d "$dest_dir" ]; then
        error "Destination directory does not exist: $dest_dir"
        return 1
    fi
    
    local applied_count=0
    local failed_count=0
    
    while IFS= read -r file; do
        local rel_path="${file#$patch_dir/}"
        local dest_file="$dest_dir/$rel_path"
        local dest_parent=$(dirname "$dest_file")
        
        if [ ! -d "$dest_parent" ]; then
            mkdir -p "$dest_parent"
            if [ $? -ne 0 ]; then
                error "Failed to create directory: $dest_parent"
                failed_count=$((failed_count + 1))
                continue
            fi
        fi
        
        cp "$file" "$dest_file"
        if [ $? -eq 0 ]; then
            info "Applied: $rel_path"
            applied_count=$((applied_count + 1))
        else
            error "Failed to apply: $rel_path"
            failed_count=$((failed_count + 1))
        fi
    done < <(find "$patch_dir" -type f)
    
    if [ "$failed_count" -eq 0 ]; then
        success "$description applied successfully ($applied_count files)"
    else
        warning "$description completed with $failed_count failures ($applied_count successful)"
    fi
    
    return $failed_count
}

validate_environment() {
    if [ -z "$RELEASE_TYPE" ]; then
        error "RELEASE_TYPE not specified"
        return 1
    fi
    
    if [ ! -d "$IMMORTALWRT_DIR" ]; then
        error "ImmortalWRT directory does not exist: $IMMORTALWRT_DIR"
        return 1
    fi
    
    if [ ! -d "$PATCH_BASE_DIR" ]; then
        error "Patch base directory does not exist: $PATCH_BASE_DIR"
        return 1
    fi
    
    return 0
}

main() {
    section "BananaWRT Patch Manager"
    info "Release Type: $RELEASE_TYPE"
    info "ImmortalWRT Directory: $IMMORTALWRT_DIR"
    info "Patch Base Directory: $PATCH_BASE_DIR"
    
    if ! validate_environment; then
        exit 1
    fi
    
    local total_failed=0
    
    apply_patches "kernel/dts" "" "$IMMORTALWRT_DIR/target/linux/mediatek/dts" "Device Tree Source patches"
    total_failed=$((total_failed + $?))
    
    apply_patches "kernel/files" "" "$IMMORTALWRT_DIR/target/linux/mediatek/files" "Kernel files patches"
    total_failed=$((total_failed + $?))
    
    echo ""
    if [ "$total_failed" -eq 0 ]; then
        success "All patches applied successfully!"
        return 0
    else
        error "Patch application completed with $total_failed total failures"
        return 1
    fi
}

case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [RELEASE_TYPE] [IMMORTALWRT_DIR]"
        echo ""
        echo "Arguments:"
        echo "  RELEASE_TYPE     Release type (stable, nightly) - default: stable"
        echo "  IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory"
        echo ""
        echo "Examples:"
        echo "  $0 stable /path/to/immortalwrt"
        echo "  $0 nightly"
        echo ""
        exit 0
        ;;
esac

main "$@"