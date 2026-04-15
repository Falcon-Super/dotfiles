#!/usr/bin/env bash
#
# Bluefin Dotfiles Setup Script
# Clones repo, applies chezmoi, runs brew bundle, configures ZSH + Atuin
# Optimized for idempotency: safe to run multiple times
#
set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
readonly DOTFILES_REPO="https://github.com/Falcon-Super/dotfiles.git"
readonly DOTFILES_DIR="$HOME/dotfiles"
readonly BREW_PREFIX="/home/linuxbrew/.linuxbrew"
readonly BREW_ZSH="$BREW_PREFIX/bin/zsh"
readonly ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ============================================================================
# LOGGING UTILITIES
# ============================================================================
declare -A COLORS=(
    [red]='\033[0;31m'
    [green]='\033[0;32m'
    [yellow]='\033[1;33m'
    [blue]='\033[0;34m'
    [nc]='\033[0m'
)

log() {
    local level="${1:-info}"
    shift
    local color="${COLORS[$level]:-${COLORS[nc]}}"
    echo -e "${color}[${level^^}]${COLORS[nc]} $*" >&2
}

log_info()    { log info "$@"; }
log_warn()    { log warn "$@"; }
log_error()   { log error "$@"; }
log_success() { log green "$@"; }

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================
check_prereqs() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    # Git
    command -v git &>/dev/null || missing+=("git")
    
    # Zsh (prefer Homebrew version)
    if [[ -x "$BREW_ZSH" ]]; then
        export ZSH="$BREW_ZSH"
    elif command -v zsh &>/dev/null; then
        log_warn "Using system zsh; consider: brew install zsh"
    else
        missing+=("zsh")
    fi
    
    # Homebrew (Linuxbrew)
    if [[ ! -d "$BREW_PREFIX" ]]; then
        log_error "Linuxbrew not found at $BREW_PREFIX"
        log_error "Install from: https://docs.brew.sh/Homebrew-on-Linux"
        exit 1
    fi
    
    # Ensure brew is in PATH for this script session
    eval "$($BREW_PREFIX/bin/brew shellenv)"
    
    # Install missing tools via brew
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Installing missing prerequisites: ${missing[*]}"
        brew install "${missing[@]}"
    fi
    
    # Chezmoi
    if ! command -v chezmoi &>/dev/null; then
        log_info "Installing chezmoi..."
        brew install chezmoi
    fi
    
    log_success "Prerequisites satisfied."
}

# ============================================================================
# CLONE DOTFILES REPO
# ============================================================================
clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        log_info "Dotfiles repo exists at $DOTFILES_DIR — pulling latest..."
        git -C "$DOTFILES_DIR" pull --rebase --autostash
    else
        log_info "Cloning dotfiles repo to $DOTFILES_DIR..."
        git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
}

# ============================================================================
# CHEZMOI SETUP & APPLY
# ============================================================================
setup_chezmoi() {
    log_info "Configuring chezmoi..."
    
    # Check if chezmoi is already initialized
    if [[ -f "$HOME/.config/chezmoi/chezmoi.toml" ]] || [[ -d "$HOME/.local/share/chezmoi" ]]; then
        log_warn "Chezmoi appears initialized. Updating source path..."
    fi
    
    # Initialize or re-init with correct source/destination
    chezmoi init --source "$DOTFILES_DIR" --destination "$HOME" --force 2>/dev/null || true
    
    log_info "Applying dotfiles with chezmoi..."
    chezmoi apply --verbose --force
}

# ============================================================================
# BREW BUNDLE
# ============================================================================
run_brew_bundle() {
    local brew_dir="$DOTFILES_DIR/Brew"
    local brewfile="$brew_dir/Brewfile"
    
    if [[ -f "$brewfile" ]]; then
        log_info "Running brew bundle in $brew_dir..."
        pushd "$brew_dir" >/dev/null
        eval "$($BREW_PREFIX/bin/brew shellenv)"
        brew bundle --verbose --no-lock
        popd >/dev/null
    else
        log_warn "No Brewfile found at $brewfile — skipping brew bundle."
    fi
}

# ============================================================================
# OH-MY-ZSH + PLUGINS SETUP
# ============================================================================
setup_zsh_plugins() {
    log_info "Setting up Oh My Zsh and plugins..."
    
    # Install Oh My Zsh if missing
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
    
    # Define plugins to install
    declare -A plugins=(
        [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
        [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )
    
    for plugin_name in "${!plugins[@]}"; do
        local plugin_url="${plugins[$plugin_name]}"
        local plugin_path="$ZSH_CUSTOM/plugins/$plugin_name"
        
        if [[ -d "$plugin_path" ]]; then
            log_info "Plugin $plugin_name already exists — pulling updates..."
            git -C "$plugin_path" pull --rebase
        else
            log_info "Cloning $plugin_name plugin..."
            git clone --depth 1 "$plugin_url" "$plugin_path"
        fi
    done
    
    log_success "ZSH plugins configured."
}

# ============================================================================
# ATUIN SETUP
# ============================================================================
setup_atuin() {
    log_info "Setting up Atuin..."
    
    # Install if missing
    if ! command -v atuin &>/dev/null; then
        log_info "Installing atuin via Homebrew..."
        brew install atuin
    fi
    
    # Ensure init line is in .zshrc (idempotent)
    local init_cmd='eval "$(atuin init zsh)"'
    if ! grep -Fxq "$init_cmd" "$HOME/.zshrc" 2>/dev/null; then
        log_info "Adding atuin init to ~/.zshrc..."
        echo "$init_cmd" >> "$HOME/.zshrc"
    fi
    
    # Check login status (non-blocking)
    if ! atuin account status &>/dev/null; then
        log_warn "Atuin not authenticated. Run 'atuin login' to enable sync."
    else
        log_success "Atuin is authenticated and ready."
    fi
}

# ============================================================================
# POST-SETUP VERIFICATION
# ============================================================================
verify_setup() {
    log_info "Running quick verification..."
    
    local checks=(
        "test -d $DOTFILES_DIR:dotfiles directory"
        "test -f $HOME/.zshrc:.zshrc exists"
        "command -v chezmoi:chezmoi in PATH"
        "command -v atuin:atuin in PATH"
        "test -d $ZSH_CUSTOM/plugins/zsh-autosuggestions:autosuggestions plugin"
        "test -d $ZSH_CUSTOM/plugins/zsh-syntax-highlighting:syntax-highlighting plugin"
    )
    
    local failed=0
    for check in "${checks[@]}"; do
        IFS=':' read -r cmd desc <<< "$check"
        if eval "$cmd" &>/dev/null; then
            log_success "✓ $desc"
        else
            log_warn "✗ $desc"
            ((failed++)) || true
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        log_success "All verification checks passed!"
    else
        log_warn "$failed check(s) failed — review output above."
    fi
}

# ============================================================================
# FINALIZE
# ============================================================================
finalize() {
    echo
    log_success "✅ Bluefin dotfiles setup complete!"
    echo
    echo "📋 Next steps:"
    echo "   • Restart your terminal or run: exec $BREW_ZSH"
    echo "   • In Ptyxis: Settings → Profile → Command → Use custom command: $BREW_ZSH"
    echo "   • Enable Atuin sync (optional): atuin login"
    echo "   • Verify plugins: echo \$plugins"
    echo
    echo "🔧 Troubleshooting:"
    echo "   • If zsh plugins don't load: source ~/.zshrc"
    echo "   • If brew commands fail: eval \"\$(brew shellenv)\""
    echo "   • Re-run this script anytime to update — it's idempotent!"
    echo
    echo "🎉 Enjoy your Bluefin environment, Salman!"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log_info "Starting Bluefin dotfiles setup for: $USER @ $(hostname)"
    echo
    
    check_prereqs
    clone_dotfiles
    setup_chezmoi
    run_brew_bundle
    setup_zsh_plugins
    setup_atuin
    verify_setup
    finalize
}

# Entry point with optional help
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo "Bluefin dotfiles setup — idempotent and safe to re-run"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --verbose     Enable debug output (WIP)"
        exit 0
        ;;
esac

main "$@"
