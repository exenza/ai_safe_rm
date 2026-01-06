#!/bin/bash

# Safe RM Installer
# Installs safe-rm as a replacement for the dangerous rm command

# More robust error handling instead of set -e
# Note: set -u removed to avoid issues when sourcing in different shells

# Parse command line arguments
FORCE_INSTALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-f|--force] [-h|--help]"
            echo "  -f, --force    Skip hash verification (use with caution)"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Detect if we're in an SSH session or sourced script
IS_SSH_SESSION=false
IS_SOURCED=false

if [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CONNECTION:-}" ]; then
    IS_SSH_SESSION=true
fi

# Check if script is being sourced - improved detection
IS_SOURCED=false
# Check if we're in an interactive shell and $0 contains shell name
if [[ "$0" == *"zsh"* ]] || [[ "$0" == *"bash"* ]] || [[ "$0" == "-"* ]]; then
    IS_SOURCED=true
fi

# Safe exit function that won't kill SSH sessions
safe_exit() {
    local exit_code=${1:-0}
    if [ "$IS_SSH_SESSION" = true ] || [ "$IS_SOURCED" = true ]; then
        print_warning "Script terminating (exit code: $exit_code)"
        print_info "SSH session preserved"
        return $exit_code
    else
        exit $exit_code
    fi
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAFE_RM_SCRIPT="$SCRIPT_DIR/safe-rm.sh"

# Expected SHA256 hash of the correct safe-rm.sh file
EXPECTED_HASH="38c789d1ce4bb95d28aae838d81048ab1d9f2bc33f0649063a9d074e6650a74d"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Check if sourced and exit early with message
if [ "$IS_SOURCED" = true ]; then
    print_error "This script should not be sourced!"
    print_info "Please run it directly instead:"
    print_info "  chmod +x ./install.sh"
    print_info "  ./install.sh"
    return 1
fi

# Function to show header
show_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Safe RM Installer                         ║"
    echo "║                                                              ║"
    echo "║  Replaces the dangerous 'rm' command with a safe version     ║"
    echo "║  that moves files to ~/.Trash instead of deleting them       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to normalize line endings and verify hash
normalize_and_verify() {
    local file="$1"
    local temp_file="${file}.normalized"
    
    print_info "Normalizing line endings..."
    
    # Convert CRLF to LF and remove trailing whitespace
    if command -v dos2unix >/dev/null 2>&1; then
        # Use dos2unix if available
        cp "$file" "$temp_file"
        dos2unix "$temp_file" >/dev/null 2>&1
    elif command -v tr >/dev/null 2>&1; then
        # Use tr to convert line endings
        tr -d '\r' < "$file" > "$temp_file"
    else
        # Fallback using sed
        sed 's/\r$//' "$file" > "$temp_file"
    fi
    
    # Remove trailing whitespace from each line
    if command -v sed >/dev/null 2>&1; then
        sed 's/[[:space:]]*$//' "$temp_file" > "${temp_file}.clean"
        mv "${temp_file}.clean" "$temp_file"
    fi
    
    # Calculate hash of normalized file
    local hash_cmd=""
    if command -v sha256sum >/dev/null 2>&1; then
        hash_cmd="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        hash_cmd="shasum -a 256"
    else
        print_warning "No SHA256 utility found - skipping verification"
        rm -f "$temp_file"
        return 0
    fi
    
    local normalized_hash
    if [ "$hash_cmd" = "sha256sum" ]; then
        normalized_hash=$(sha256sum "$temp_file" 2>/dev/null | cut -d' ' -f1)
    else
        normalized_hash=$(shasum -a 256 "$temp_file" 2>/dev/null | cut -d' ' -f1)
    fi
    
    if [ "$normalized_hash" = "$EXPECTED_HASH" ]; then
        print_success "Hash verification passed after normalization ✓"
        # Replace original with normalized version
        mv "$temp_file" "$file"
        return 0
    else
        print_warning "Hash still doesn't match after normalization"
        print_info "Expected: $EXPECTED_HASH"
        print_info "Actual:   $normalized_hash"
        rm -f "$temp_file"
        return 1
    fi
}

# Function to verify safe-rm.sh integrity
verify_safe_rm_hash() {
    local file="$1"
    
    # Check if we have sha256sum or shasum
    local hash_cmd=""
    if command -v sha256sum >/dev/null 2>&1; then
        hash_cmd="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        hash_cmd="shasum -a 256"
    else
        print_warning "No SHA256 utility found (sha256sum or shasum)"
        print_warning "Skipping hash verification - proceed with caution!"
        return 0
    fi
    
    print_info "Verifying safe-rm.sh integrity..."
    
    # Calculate hash
    local actual_hash
    if [ "$hash_cmd" = "sha256sum" ]; then
        actual_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    else
        actual_hash=$(shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1)
    fi
    
    if [ -z "$actual_hash" ]; then
        print_error "Failed to calculate hash for $file"
        return 1
    fi
    
    # Compare hashes
    if [ "$actual_hash" = "$EXPECTED_HASH" ]; then
        print_success "Hash verification passed ✓"
        return 0
    else
        print_info "Hash mismatch detected - attempting to normalize line endings..."
        print_info "Original hash: $actual_hash"
        
        # Try to normalize and verify
        if normalize_and_verify "$file"; then
            return 0
        else
            print_error "Hash verification FAILED even after normalization!"
            print_error "Expected: $EXPECTED_HASH"
            print_error "Actual:   $actual_hash"
            return 1
        fi
    fi
}



# Function to check if safe-rm.sh exists
check_safe_rm() {
    if [ ! -f "$SAFE_RM_SCRIPT" ]; then
        print_error "safe-rm.sh not found"
        print_info "Please ensure safe-rm.sh is in: $SCRIPT_DIR"
        return 1
    fi
    
    # Skip hash verification if force flag is used
    if [ "$FORCE_INSTALL" = true ]; then
        print_warning "Skipping hash verification due to -f flag"
        print_warning "Installing without verification - use with caution!"
    else
        # Verify hash
        if ! verify_safe_rm_hash "$SAFE_RM_SCRIPT"; then
            print_error "safe-rm.sh failed integrity check"
            print_info "Please ensure you have the correct, complete safe-rm.sh file"
            print_info "Or use -f flag to skip verification (not recommended)"
            return 1
        fi
    fi
    
    if [ ! -x "$SAFE_RM_SCRIPT" ]; then
        print_info "Making safe-rm.sh executable..."
        chmod +x "$SAFE_RM_SCRIPT" || {
            print_error "Failed to make safe-rm.sh executable"
            return 1
        }
    fi
    
    if [ "$FORCE_INSTALL" = true ]; then
        print_success "Found safe-rm.sh script (verification skipped)"
    else
        print_success "Found and verified safe-rm.sh script"
    fi
    return 0
}

# Function to detect existing installations
detect_existing_installations() {
    local existing_types=()
    
    # Check for system-wide installation
    if [ -f /usr/local/bin/rm ]; then
        existing_types+=("system-wide")
    fi
    
    # Check for user binary installation
    if [ -f "$HOME/bin/rm" ]; then
        existing_types+=("user-binary")
    fi
    
    # Check for user alias
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$rc" ] && grep -q "alias rm.*safe-rm" "$rc" 2>/dev/null; then
            existing_types+=("user-alias")
            break
        fi
    done
    
    if [ ${#existing_types[@]} -gt 0 ]; then
        print_warning "Existing safe-rm installation(s) detected:"
        for type in "${existing_types[@]}"; do
            echo "  • $type"
        done
        echo ""
        return 0
    else
        return 1
    fi
}

# Function to check installation conflicts
check_installation_conflict() {
    local install_type="$1"
    local conflicts=()
    
    case "$install_type" in
        "alias")
            # Alias conflicts with system-wide and user-binary
            [ -f /usr/local/bin/rm ] && conflicts+=("system-wide")
            [ -f "$HOME/bin/rm" ] && conflicts+=("user-binary")
            ;;
        "binary")
            # Binary conflicts with system-wide
            [ -f /usr/local/bin/rm ] && conflicts+=("system-wide")
            ;;
        "system")
            # System-wide conflicts with everything
            [ -f "$HOME/bin/rm" ] && conflicts+=("user-binary")
            for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
                if [ -f "$rc" ] && grep -q "alias rm.*safe-rm" "$rc" 2>/dev/null; then
                    conflicts+=("user-alias")
                    break
                fi
            done
            ;;
    esac
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        print_warning "Installation conflict detected!"
        print_info "Installing $install_type method will conflict with existing:"
        for conflict in "${conflicts[@]}"; do
            echo "  • $conflict installation"
        done
        echo ""
        print_info "Recommendation: Uninstall existing installations first (option 5)"
        echo ""
        echo -n "Continue anyway? [y/N]: "
        read -r response
        case $response in
            [Yy]|[Yy][Ee][Ss]) 
                print_warning "Proceeding with conflicting installation..."
                return 0 
                ;;
            *) 
                print_info "Installation cancelled"
                return 1 
                ;;
        esac
    fi
    
    return 0
}
install_user_alias() {
    # Check for conflicts
    if ! check_installation_conflict "alias"; then
        return 1
    fi
    
    print_info "Installing safe-rm for current user (alias method)..."
    
    # Detect shell
    SHELL_RC=""
    if [ -n "${ZSH_VERSION:-}" ] || [[ "${SHELL:-}" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ] || [[ "${SHELL:-}" == *"bash"* ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        print_warning "Unknown shell. Defaulting to .bashrc"
        SHELL_RC="$HOME/.bashrc"
    fi
    
    # Create shell rc file if it doesn't exist
    touch "$SHELL_RC" || {
        print_error "Failed to create $SHELL_RC"
        return 1
    }
    
    # Remove existing safe-rm aliases
    if grep -q "alias rm.*safe-rm" "$SHELL_RC" 2>/dev/null; then
        print_info "Removing existing safe-rm alias..."
        sed -i.bak '/alias rm.*safe-rm/d' "$SHELL_RC" || {
            print_warning "Could not remove existing alias, continuing..."
        }
    fi
    
    # Add new alias
    {
        echo ""
        echo "# Safe RM - moves files to trash instead of deleting"
        echo "alias rm='$SAFE_RM_SCRIPT'"
        echo "# Use \\rm to access original rm when needed"
    } >> "$SHELL_RC" || {
        print_error "Failed to add alias to $SHELL_RC"
        return 1
    }
    
    print_success "Alias installed in $SHELL_RC"
    print_info "Restart your terminal or run: source $SHELL_RC"
    print_info "Use '\\rm' (backslash-rm) to access the original rm command when needed"
    return 0
}

install_user_binary() {
    # Check for conflicts
    if ! check_installation_conflict "binary"; then
        return 1
    fi
    
    print_info "Installing safe-rm for current user (binary method)..."
    
    # Create ~/bin directory
    mkdir -p "$HOME/bin"
    
    # Copy script
    cp "$SAFE_RM_SCRIPT" "$HOME/bin/rm"
    chmod +x "$HOME/bin/rm"
    
    # Create symlink to original rm
    ln -sf /bin/rm "$HOME/bin/rm.real"
    
    # Update PATH in shell rc
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ] || [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [[ "$SHELL" == *"bash"* ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
    
    # Add PATH if not already there
    if ! grep -q 'PATH.*$HOME/bin' "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Add ~/bin to PATH for safe-rm" >> "$SHELL_RC"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    fi
    
    print_success "Binary installed in ~/bin/rm"
    print_info "Restart your terminal or run: source $SHELL_RC"
    print_info "Use 'rm.real' to access the original rm command when needed"
}

# Function for system-wide installation
install_system_wide() {
    # Check for conflicts
    if ! check_installation_conflict "system"; then
        return 1
    fi
    
    print_info "Installing safe-rm system-wide..."
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        print_info "This installation requires administrator privileges"
        print_info "You may be prompted for your password"
    fi
    
    # Install to /usr/local/bin
    print_info "Installing to /usr/local/bin/rm..."
    sudo cp "$SAFE_RM_SCRIPT" /usr/local/bin/rm
    sudo chmod +x /usr/local/bin/rm
    
    # Create symlink to original rm
    print_info "Creating symlink to original rm..."
    sudo ln -sf /bin/rm /usr/local/bin/rm.real
    
    # Ensure /usr/local/bin is in system PATH
    if [ ! -f /etc/paths.d/safe-rm ]; then
        print_info "Adding /usr/local/bin to system PATH..."
        echo "/usr/local/bin" | sudo tee /etc/paths.d/safe-rm > /dev/null
    fi
    
    print_success "System-wide installation complete!"
    print_info "All users will now use safe-rm by default"
    print_info "Use 'rm.real' to access the original rm command when needed"
    print_warning "You may need to restart terminal sessions for changes to take effect"
}

# Function to uninstall
uninstall() {
    print_info "Uninstalling safe-rm..."
    
    # Remove user alias
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [ -f "$rc" ] && grep -q "safe-rm" "$rc"; then
            print_info "Removing alias from $rc..."
            sed -i.bak '/safe-rm/d' "$rc"
            sed -i.bak '/alias rm.*safe-rm/d' "$rc"
            sed -i.bak '/# Use.*rm.*access original/d' "$rc"
        fi
    done
    
    # Remove user binary
    if [ -f "$HOME/bin/rm" ]; then
        print_info "Removing ~/bin/rm..."
        rm -f "$HOME/bin/rm" "$HOME/bin/rm.real"
    fi
    
    # Remove system-wide (requires sudo)
    if [ -f /usr/local/bin/rm ]; then
        print_info "Removing system-wide installation (requires sudo)..."
        sudo rm -f /usr/local/bin/rm /usr/local/bin/rm.real
        sudo rm -f /etc/paths.d/safe-rm
    fi
    
    print_success "Uninstallation complete!"
    print_info "Restart your terminal for changes to take effect"
}

# Function to show current status
show_status() {
    print_info "Current safe-rm installation status:"
    echo ""
    
    # Check which rm is being used
    RM_PATH=$(which rm 2>/dev/null || echo "not found")
    echo "Current 'rm' command: $RM_PATH"
    
    # Check for aliases
    if alias rm 2>/dev/null | grep -q safe-rm; then
        echo "✓ User alias found"
    fi
    
    # Check for user binary
    if [ -f "$HOME/bin/rm" ]; then
        echo "✓ User binary found: ~/bin/rm"
    fi
    
    # Check for system binary
    if [ -f /usr/local/bin/rm ]; then
        echo "✓ System binary found: /usr/local/bin/rm"
    fi
    
    # Check trash directory
    if [ -d "$HOME/.Trash" ]; then
        TRASH_COUNT=$(ls -1 "$HOME/.Trash" 2>/dev/null | wc -l)
        echo "Trash directory: ~/.Trash ($TRASH_COUNT items)"
    else
        echo "Trash directory: ~/.Trash (not created yet)"
    fi
}

# Main menu
show_menu() {
    echo ""
    print_info "Choose installation method:"
    echo ""
    echo "1) User-level (alias method)     - Safest, only affects current user"
    echo "2) User-level (binary method)    - Affects current user, works with scripts"
    echo "3) System-wide                   - Affects all users (requires sudo)"
    echo "4) Show current status"
    echo "5) Uninstall safe-rm"
    echo "6) Exit"
    echo ""
}

# Main script
main() {
    show_header
    
    # Show SSH session warning
    if [ "$IS_SSH_SESSION" = true ]; then
        print_info "SSH session detected - script will not terminate your connection"
        echo ""
    fi
    
    # Show force flag warning
    if [ "$FORCE_INSTALL" = true ]; then
        print_warning "FORCE MODE: Hash verification disabled!"
        print_warning "This bypasses security checks - use only if you trust the source"
        echo ""
    fi
    
    # Check if safe-rm.sh exists, exit gracefully if not
    if ! check_safe_rm; then
        echo ""
        print_info "Installation cannot proceed without safe-rm.sh"
        print_info "Please copy safe-rm.sh to the same directory as this installer and try again"
        safe_exit 1
        return 1
    fi
    
    # Show existing installations
    if detect_existing_installations; then
        print_info "You can uninstall existing installations using option 5"
        echo ""
    fi
    
    while true; do
        show_menu
        read -p "Enter your choice (1-6): " choice
        
        case $choice in
            1)
                install_user_alias
                break
                ;;
            2)
                install_user_binary
                break
                ;;
            3)
                install_system_wide
                break
                ;;
            4)
                show_status
                ;;
            5)
                uninstall
                safe_exit 0
                return 0
                ;;
            6)
                print_info "Installation cancelled"
                safe_exit 0
                return 0
                ;;
            *)
                print_error "Invalid choice. Please enter 1-6."
                ;;
        esac
    done
    
    echo ""
    print_success "Installation complete!"
    print_info "Your files are now protected from accidental deletion"
    print_warning "Remember: deleted files go to ~/.Trash and can be restored manually"
    print_info "Use 'rm -e' to empty the trash permanently"
}

# Run main function only if script is executed, not sourced
if [ "$IS_SOURCED" = false ]; then
    main "$@"
fi