#!/bin/bash

# Void Linux Setup Script
# =======================
# This script automates the installation and configuration of a Void Linux system.
# It includes system updates, package installation, development environment setup,
# and user configuration management.

# Script Configuration
# ====================
set -euo pipefail  # Exit on error, undefined variables, and pipe failures
set -x            # Print each command before execution for transparency

# Color codes for verbose output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# Function to check if running with sudo privileges
check_privileges() {
    log_info "Checking user privileges..."
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root user - some user-specific operations may not work correctly"
    elif sudo -n true 2>/dev/null; then
        log_success "User has sudo privileges"
    else
        log_error "This script requires sudo privileges. Please run as root or with sudo."
        exit 1
    fi
}

# Function to check if we're in the first run (needs reboot) or second run
is_first_run() {
    # Check if non-free repositories are already installed
    if xbps-query -l | grep -q void-repo-nonfree; then
        log_debug "Non-free repositories detected - assuming second run"
        return 1
    else
        log_debug "Non-free repositories not found - assuming first run"
        return 0
    fi
}

# Phase 1: System Update and Preparation
# ======================================
system_update() {
    log_info "Starting Phase 1: System Update and Preparation"
    
    log_info "Synchronizing package database..."
    sudo xbps-install -Sy
    
    log_info "Updating xbps package manager..."
    sudo xbps-install -u xbps
    
    log_info "Performing full system upgrade..."
    sudo xbps-install -Su
    
    log_success "System update completed successfully"
}

# Phase 2: Repository Configuration
# =================================
configure_repositories() {
    log_info "Starting Phase 2: Repository Configuration"
    
    log_info "Adding non-free and multilib repositories for additional software..."
    log_debug "void-repo-nonfree: Provides non-free software packages"
    log_debug "void-repo-multilib: Provides 32-bit libraries for compatibility"
    log_debug "void-repo-multilib-nonfree: Provides non-free 32-bit libraries"
    
    sudo xbps-install -Sy void-repo-nonfree void-repo-multilib-nonfree void-repo-multilib
    
    log_success "Additional repositories configured successfully"
}

# Phase 3: Package Installation
# =============================
package_installation() {
    log_info "Starting Phase 3: Package Installation"
    
    # Categorized package installation for better transparency and organization
    local PACKAGES=()
    
    # Development Tools and Programming Environments
    log_info "Adding development tools..."
    PACKAGES+=(helix git chezmoi uv rustup github-cli fastfetch)
    log_debug "helix: Modern text editor"
    log_debug "git: Version control system"
    log_debug "chezmoi: Dotfiles manager"
    log_debug "uv: Fast Python package installer and resolver"
    log_debug "rustup: Rust toolchain installer"
    log_debug "github-cli: Official GitHub command line tool"
    
    # Fonts and Terminal
    log_info "Adding terminal and font packages..."
    PACKAGES+=(nerd-fonts ghostty)
    log_debug "nerd-fonts: Iconic font aggregator for developers"
    log_debug "ghostty: Modern, feature-rich terminal emulator"
    
    # Graphics and GPU Support (AMD-specific)
    log_info "Adding AMD graphics and GPU support..."
    PACKAGES+=(amdvlk xf86-video-amdgpu mesa-vaapi mesa-vdpau)
    log_debug "amdvlk: Open-source Vulkan driver for AMD GPUs"
    log_debug "xf86-video-amdgpu: Xorg driver for AMD GPUs"
    log_debug "mesa-vaapi: VA-API support for Mesa"
    log_debug "mesa-vdpau: VDPAU support for Mesa"
    
    # 32-bit Libraries (for Steam and compatibility)
    log_info "Adding 32-bit compatibility libraries..."
    PACKAGES+=(libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit)
    PACKAGES+=(libva-32bit mesa-dri-32bit)
    log_debug "32-bit libraries: Required for Steam and other compatibility software"
    
    # Applications
    log_info "Adding desktop applications..."
    PACKAGES+=(steam telegram-desktop chromium libreoffice vlc mpv celluloid gearlever mugshot)
    log_debug "steam: Gaming platform"
    log_debug "telegram-desktop: Messaging application"
    log_debug "chromium: Web browser"
    log_debug "libreoffice: Office suite"
    log_debug "vlc: Media player"
    log_debug "mpv: Video player"
    log_debug "celluloid: Simple GTK+ frontend for mpv"
    log_debug "gearlever: GUI for Appimages"
    log_debug "mugshot: User profile configuration tool"
    
    # System Monitoring and Utilities
    log_info "Adding system utilities and monitoring tools..."
    PACKAGES+=(btop bat fd tealdeer fzf jq yq vsv vpm)
    log_debug "btop: Resource monitor"
    log_debug "bat: Cat clone with syntax highlighting"
    log_debug "fd: Simple and fast alternative to find"
    log_debug "tealdeer: Fast tldr client"
    log_debug "fzf: Command-line fuzzy finder"
    log_debug "jq: JSON processor"
    log_debug "yq: YAML processor"
    log_debug "vsv: Void service manager"
    log_debug "vpm: Void package manager helper"
    
    # Shell and Development Environment
    log_info "Adding shell and development environment packages..."
    PACKAGES+=(zsh zsh-autosuggestions zsh-syntax-highlighting wget atuin gitui xfce4-plugins)
    log_debug "zsh: Z shell with extensive customization"
    log_debug "zsh-autosuggestions: Fish-like suggestions for Zsh"
    log_debug "zsh-syntax-highlighting: Syntax highlighting for Zsh"
    log_debug "wget: Network downloader"
    log_debug "atuin: Magical shell history"
    log_debug "gitui: Terminal UI for git"
    log_debug "xfce4-plugins: Additional plugins for XFCE"
    
    log_info "Installing ${#PACKAGES[@]} packages in categorized groups..."
    log_debug "Full package list: ${PACKAGES[*]}"
    
    # Install all packages in a single transaction for better dependency resolution
    sudo xbps-install -Sy "${PACKAGES[@]}"
    
    log_success "All packages installed successfully"
}

# Phase 4: Rust Toolchain Setup
# =============================
setup_rust_toolchain() {
    log_info "Starting Phase 4: Rust Toolchain Setup"
    
    log_info "Running rustup initialization..."
    log_debug "rustup was installed from Void repositories, now setting up toolchain"
    
    # Initialize rustup and install stable toolchain
    rustup default stable
    
    log_success "Rust toolchain configured successfully"
    log_info "Rust version: $(rustc --version)"
    log_info "Cargo version: $(cargo --version)"
}

# Phase 5: Configuration Management
# =================================
apply_configurations() {
    log_info "Starting Phase 5: Configuration Management"
    
    log_info "Initializing and applying chezmoi configurations..."
    log_info "Using configuration repository: Falcon-Super"
    log_debug "chezmoi will pull dotfiles and configurations from the specified repository"
    
    chezmoi init --apply Falcon-Super
    
    log_success "Configuration files applied successfully"
}

# Phase 6: Additional Software Installation
# ========================================
additional_software() {
    log_info "Starting Phase 6: Additional Software Installation"
    
    # LibreWolf Browser Installation
    log_info "Setting up LibreWolf browser..."
    log_debug "LibreWolf is a privacy-focused fork of Firefox"
    
    # Create configuration directory if it doesn't exist
    sudo mkdir -p /etc/xbps.d
    log_debug "Created xbps configuration directory: /etc/xbps.d"
    
    # Configure LibreWolf repository
    log_info "Configuring LibreWolf repository..."
    echo "repository=https://github.com/index-0/librewolf-void/releases/latest/download/" | sudo tee /etc/xbps.d/20-librewolf.conf
    log_debug "Added LibreWolf repository configuration to /etc/xbps.d/20-librewolf.conf"
    
    # Install LibreWolf
    sudo xbps-install -Su librewolf
    
    log_success "LibreWolf installed successfully"
}

# Phase 7: Development Environment Setup
# ======================================
development_setup() {
    log_info "Starting Phase 7: Development Environment Setup"
    
    # Install Ruff Python linter using UV (installed from Void repos)
    log_info "Installing Ruff Python linter using UV..."
    log_debug "Ruff is an extremely fast Python linter and code formatter"
    
    uv tool install ruff@latest
    
    log_success "Ruff installed successfully"
    log_info "Ruff version: $(ruff --version 2>/dev/null || echo 'Ruff not in PATH')"
    
    # Note: UV is already installed from Void repositories, so no need for curl installation
    log_info "UV package manager is available from system installation"
    log_info "UV version: $(uv --version 2>/dev/null || echo 'UV not in PATH')"
}

# Phase 8: Shell Configuration
# ============================
shell_setup() {
    log_info "Starting Phase 8: Shell Configuration"
    
    # Change default shell to ZSH
    log_info "Changing default shell to ZSH..."
    local current_shell="$(getent passwd $USER | cut -d: -f7)"
    local zsh_path="/usr/bin/zsh"
    
    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_info "Current shell: $current_shell"
        log_info "Changing to: $zsh_path"
        chsh -s "$zsh_path"
        log_success "Default shell changed to ZSH"
    else
        log_info "ZSH is already the default shell"
    fi
    
    # Install Oh My Zsh
    log_info "Installing Oh My Zsh framework..."
    log_debug "Oh My Zsh is a community-driven framework for Zsh configuration"
    log_debug "Running in unattended mode to avoid auto-changing shell"
    
    # Run in non-interactive mode to avoid auto-changing shell
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    log_success "Oh My Zsh installed successfully"
}

# Main Execution Flow
# ===================
main() {
    log_info "Starting Void Linux Setup Script"
    log_info "Script version: 3.0"
    log_info "Timestamp: $(date)"
    log_info "User: $USER"
    log_info "Hostname: $(hostname)"
    
    # Check if user has required privileges
    check_privileges
    
    # Determine if this is first run (needs reboot) or second run
    if is_first_run; then
        log_warning "First run detected - system update and reboot required"
        log_info "Execution phases for first run:"
        log_info "1. System Update and Preparation"
        log_info "2. Repository Configuration" 
        log_info "3. Package Installation"
        log_info "4. Rust Toolchain Setup"
        log_info "5. Configuration Management"
        log_info "6. Additional Software Installation"
        log_info "7. Development Environment Setup"
        log_info "8. Shell Configuration"
        
        # Prompt user for confirmation
        read -p "Continue with first run setup? This will require a reboot. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        
        # Execute first run phases
        system_update
        configure_repositories
        package_installation
        setup_rust_toolchain
        
        log_success "First run setup completed successfully!"
        log_warning "A system reboot is required to complete the setup."
        log_info "After reboot, please run this script again to continue."
        
        # Prompt for reboot
        read -p "Reboot now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Initiating system reboot..."
            sudo reboot
        else
            log_warning "Please remember to reboot and run this script again to complete setup"
        fi
    else
        log_success "Second run detected - continuing with remaining setup"
        log_info "Execution phases for second run:"
        log_info "1. Configuration Management"
        log_info "2. Additional Software Installation" 
        log_info "3. Development Environment Setup"
        log_info "4. Shell Configuration"
        
        # Prompt user for confirmation
        read -p "Continue with second run setup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        
        # Execute second run phases
        apply_configurations
        additional_software
        development_setup
        shell_setup
        
        # Completion message
        log_success "=========================================="
        log_success "🎉 Void Linux Setup Completed Successfully!"
        log_success "=========================================="
        log_info "Summary of installed components:"
        log_info "✓ Updated system packages and repositories"
        log_info "✓ Essential applications (Steam, LibreOffice, VLC, etc.)"
        log_info "✓ Development tools (Helix, Git, UV, Rust, Ruff)"
        log_info "✓ Shell environment (ZSH, Oh My Zsh)"
        log_info "✓ Configuration files via chezmoi"
        log_info "✓ Privacy-focused browser (LibreWolf)"
        log_info ""
        log_info "System information:"
        log_info "  Rust toolchain: $(rustc --version 2>/dev/null || echo 'Not available')"
        log_info "  UV version: $(uv --version 2>/dev/null || echo 'Not available')"
        log_info "  Default shell: $(getent passwd $USER | cut -d: -f7)"
        log_info ""
        log_warning "Important: Please log out and log back in for all changes to take effect"
        log_warning "Some changes (like default shell) may require a restart of your terminal"
        log_info ""
        log_success "Setup completed at: $(date)"
    fi
}

# Error handling and cleanup
cleanup() {
    local exit_code=$?
    local line_number=$1
    local command=$2
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed at line $line_number with exit code $exit_code"
        log_error "Failed command: $command"
        log_error "Please check the output above for error details"
    fi
    exit $exit_code
}

# Set trap for error handling
trap 'cleanup $LINENO "$BASH_COMMAND"' ERR

# Execute main function only if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
