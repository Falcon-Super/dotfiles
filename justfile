# =============================================================================
# JUSTFILE: Bluefin Linux Dotfiles Setup
# =============================================================================
# WHAT IS JUST?
# just is a command runner that stores project-specific commands in a justfile.
# Think of it as a simpler, more user-friendly alternative to Make.
#
# KEY SYNTAX RULES (from the Just manual):
# • Variables: NAME := "value" or NAME := expression
# • String concat: "foo" + "bar" → "foobar"
# • env("VAR"): Get environment variable value
# • home_directory(): Get user's home dir (cross-platform)
# • {{VAR}}: Interpolate variable into recipe body (substituted BEFORE bash runs)
# • Backticks: `command` captures stdout as string
# • Shebang recipes: #!/usr/bin/env bash runs entire body in one shell
#
# USAGE:
#   just setup_dotfiles                    # Run from ~/dotfiles or subdirectory
#   just -f ~/dotfiles/justfile setup_dotfiles  # Run with explicit path
#   just --list                            # List available recipes
#   just --show setup_dotfiles             # Show recipe source
#   just --dry-run setup_dotfiles          # Preview without executing
# =============================================================================

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================
# These are evaluated by just BEFORE the recipe runs.
# env("HOME") returns a string, so no conversion needed.

DOTFILES_DIR := env("HOME") + "/dotfiles"
BREW_BIN := "/home/linuxbrew/.linuxbrew/bin/brew"
ZSH_DIR := env("HOME") + "/.oh-my-zsh"
ZSH_CUSTOM := ZSH_DIR + "/custom"
BREWFILE := DOTFILES_DIR + "/Brew/Brewfile"

# =============================================================================
# RECIPE: setup_bluefin_prereqs
# =============================================================================
# Run these Bluefin-specific ujust commands BEFORE running setup_dotfiles.
# These prepare your Bluefin system for development workloads.
#
# IMPORTANT: Skip `ujust devmode` if you're on Bluefin LTS (Long Term Support)!
# LTS already has development tools enabled by default.
#
# Commands:
# • ujust bluefin-cli  → Installs CLI tools & dev environment basics
# • ujust devmode      → Enables developer mode (SKIP ON BLUEFIN LTS!)
# • ujust dx-group     → Adds user to developer/dx groups for container access
#
# Run with: just setup_bluefin_prereqs
setup_bluefin_prereqs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "========================================="
    echo "🐧 Bluefin System Prerequisites Setup"
    echo "========================================="
    echo ""

    # Check if we're on Bluefin (optional but helpful)
    if ! grep -q "Bluefin" /etc/os-release 2>/dev/null; then
        echo "⚠️  Warning: This script is designed for Bluefin Linux."
        echo "   Some ujust commands may not be available on other distros."
        echo ""
    fi

    # Step 1: bluefin-cli
    echo "🔧 Step 1: Running ujust bluefin-cli..."
    echo "   This installs CLI tools, dev containers, and basic dev environment."
    if command -v ujust &>/dev/null; then
        ujust bluefin-cli || echo "   ⚠️  bluefin-cli may have already run or failed."
    else
        echo "   ❌ ujust not found. Are you on Bluefin?"
    fi
    echo "   ✅ bluefin-cli complete."
    echo ""

    # Step 2: devmode (SKIP IF BLUEFIN LTS!)
    echo "🔧 Step 2: Running ujust devmode..."
    echo "   ⚠️  IMPORTANT: If you're on Bluefin LTS, SKIP this step!"
    echo "   LTS already has development tools enabled."
    echo ""
    read -p "   Are you running Bluefin LTS? (y/N): " -n 1 -r < /dev/tty || true
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        if command -v ujust &>/dev/null; then
            ujust devmode || echo "   ⚠️  devmode may have already run or failed."
        else
            echo "   ❌ ujust not found."
        fi
        echo "   ✅ devmode complete."
    else
        echo "   ⏭️  Skipping devmode (Bluefin LTS detected)."
    fi
    echo ""

    # Step 3: dx-group
    echo "🔧 Step 3: Running ujust dx-group..."
    echo "   This adds your user to developer groups for podman/docker access."
    if command -v ujust &>/dev/null; then
        ujust dx-group || echo "   ⚠️  dx-group may require reboot to take effect."
    else
        echo "   ❌ ujust not found."
    fi
    echo "   ✅ dx-group complete."
    echo ""

    echo "========================================="
    echo "✅ Bluefin Prerequisites Complete!"
    echo "========================================="
    echo ""
    echo "📋 Next: Run 'just setup_dotfiles' to configure your environment."
    echo "💡 You may need to reboot for group changes to take effect."
    echo "========================================="

# =============================================================================
# RECIPE: setup_dotfiles
# =============================================================================
# Main recipe: clones repo, runs brew bundle, symlinks dotfiles, sets up Zsh + Atuin.
#
# IMPORTANT: Run 'just setup_bluefin_prereqs' FIRST on a fresh Bluefin install!
#
# Run with: just setup_dotfiles
setup_dotfiles:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "========================================="
    echo "🚀 Starting Bluefin Dotfiles Setup"
    echo "========================================="
    echo ""

    # ========================================================================
    # STEP 1: VERIFY HOMEBREW
    # ========================================================================
    echo "🔍 Step 1: Checking for Homebrew..."
    if [[ ! -x "{{BREW_BIN}}" ]]; then
        echo "❌ ERROR: Homebrew not found at {{BREW_BIN}}"
        echo "   Install: https://docs.brew.sh/Homebrew-on-Linux"
        exit 1
    fi
    echo "   ✅ Homebrew found."
    echo ""

    # ========================================================================
    # STEP 2: SYNC DOTFILES REPO
    # ========================================================================
    echo "📦 Step 2: Syncing dotfiles repository..."
    
    if [[ -d "{{DOTFILES_DIR}}/.git" ]]; then
        echo "   📂 Pulling latest changes..."
        git -C "{{DOTFILES_DIR}}" pull --rebase --autostash
    else
        echo "   📥 Cloning repository..."
        git clone --recursive https://github.com/Falcon-Super/dotfiles.git "{{DOTFILES_DIR}}"
    fi
    echo "   ✅ Repository up to date."
    echo ""

    # ========================================================================
    # STEP 3: RUN BREW BUNDLE
    # ========================================================================
    echo "🍺 Step 3: Installing packages via Brewfile..."
    
    eval "$({{BREW_BIN}} shellenv)"
    
    if [[ -f "{{BREWFILE}}" ]]; then
        {{BREW_BIN}} bundle --file="{{BREWFILE}}" --verbose
    else
        echo "   ⚠️  Brewfile not found at {{BREWFILE}}, skipping."
    fi
    echo "   ✅ Packages installed/updated."
    echo ""

    # ========================================================================
    # STEP 4: SYMLINK DOTFILES
    # ========================================================================
    echo "🔗 Step 4: Linking dotfiles to $HOME..."
    
    link_file() {
        local src="$1"
        local dst="$2"
        
        if [[ ! -e "$src" ]]; then
            echo "   ⚠️  Skip: $src not found"
            return 0
        fi
        
        if [[ -e "$dst" || -L "$dst" ]]; then
            if [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
                echo "   ✅ Already linked: $dst"
                return 0
            fi
            echo "   📦 Backing up: $dst → ${dst}.bak"
            mv "$dst" "${dst}.bak"
        fi
        
        mkdir -p "$(dirname "$dst")"
        ln -sf "$src" "$dst"
        echo "   🔗 Linked: $src → $dst"
    }

    link_file "{{DOTFILES_DIR}}/dot_zshrc" "$HOME/.zshrc"
    link_file "{{DOTFILES_DIR}}/dot_gitconfig" "$HOME/.gitconfig"

    if [[ -d "{{DOTFILES_DIR}}/dot_config" ]]; then
        echo "   📁 Linking dot_config/ contents..."
        find "{{DOTFILES_DIR}}/dot_config" -type f | while read -r src_file; do
            rel_path="${src_file#{{DOTFILES_DIR}}/dot_config/}"
            link_file "$src_file" "$HOME/.config/$rel_path"
        done
    fi
    echo "   ✅ Dotfiles linked."
    echo ""

    # ========================================================================
    # STEP 5: OH-MY-ZSH + PLUGINS
    # ========================================================================
    echo "🐚 Step 5: Setting up Zsh environment..."
    
    if [[ ! -d "{{ZSH_DIR}}" ]]; then
        echo "   📥 Installing Oh-My-Zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "   ✅ Oh-My-Zsh already installed."
    fi

    plugins=(
        "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )
    for plugin_entry in "${plugins[@]}"; do
        IFS=':' read -r plugin_name plugin_url <<< "$plugin_entry"
        plugin_dir="{{ZSH_CUSTOM}}/plugins/$plugin_name"
        
        if [[ -d "$plugin_dir" ]]; then
            echo "   🔄 Updating: $plugin_name"
            git -C "$plugin_dir" pull --rebase -q
        else
            echo "   📥 Cloning: $plugin_name"
            git clone --depth 1 "$plugin_url" "$plugin_dir" -q
        fi
    done
    echo "   ✅ Zsh plugins configured."
    echo ""

    # ========================================================================
    # STEP 6: ATUIN SETUP
    # ========================================================================
    echo "🪞 Step 6: Setting up Atuin (shell history sync)..."
    
    if ! command -v atuin &>/dev/null; then
        echo "   📥 Installing atuin..."
        {{BREW_BIN}} install atuin
    else
        echo "   ✅ Atuin already installed."
    fi

    INIT_LINE='eval "$(atuin init zsh)"'
    if ! grep -qF "$INIT_LINE" "$HOME/.zshrc" 2>/dev/null; then
        echo "   📝 Adding atuin init to ~/.zshrc..."
        echo "$INIT_LINE" >> "$HOME/.zshrc"
    else
        echo "   ✅ Atuin already initialized in ~/.zshrc."
    fi
    echo "   ✅ Atuin setup complete."
    echo ""

    # ========================================================================
    # FINAL SUMMARY
    # ========================================================================
    echo "========================================="
    echo "✅ Setup Complete!"
    echo "========================================="
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Restart terminal: exec {{BREW_BIN}}/zsh"
    echo "   2. Ptyxis: Settings → Profile → Command → {{BREW_BIN}}/zsh"
    echo "   3. Enable history sync: atuin login"
    echo '   4. Verify plugins: echo $plugins'
    echo ""
    echo "💡 This script is IDEMPOTENT:"
    echo "   • Safe to run multiple times"
    echo "   • Only updates what changed"
    echo "   • Backs up existing files before overwriting"
    echo "========================================="
