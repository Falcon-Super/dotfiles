# 🐧 Bluefin Linux Dotfiles (just Edition)

This repository manages my development environment on **Bluefin Linux** using [`just`](https://github.com/casey/just), a simple, transparent command runner. No complex tools — just bash, git, and symlinks.

## 🎯 Philosophy
- **Minimal**: One `justfile` does everything
- **Transparent**: Every command is visible bash — no hidden magic
- **Idempotent**: Safe to run 1 or 100 times
- **Bluefin-native**: Works with `/var/home`, Linuxbrew, and immutable OS

## 📁 Repository Structure
```
dotfiles/
├── README.md              ← You are here
├── justfile               ← Main setup script (run with `just`)
├── Brew/
│   └── Brewfile           ← Homebrew packages to install
├── dot_config/            ← Config files for ~/.config/
│   ├── fastfetch/
│   ├── ghostty/
│   ├── helix/
│   └── scripts/
├── dot_gitconfig          ← ~/.gitconfig source
└── dot_zshrc              ← ~/.zshrc source
```

## 🚀 Quick Start

### 🔧 Step 0: Bluefin System Prerequisites (FIRST TIME ONLY)
> ⚠️ **Run these BEFORE `just setup_dotfiles` on a fresh Bluefin install!**

```bash
# 1. Install CLI tools & dev environment
ujust bluefin-cli

# 2. Enable developer mode (SKIP IF ON BLUEFIN LTS!)
#    LTS already has dev tools enabled — do NOT run this on LTS
ujust devmode

# 3. Add user to developer groups (for podman/docker access)
ujust dx-group

# 💡 You may need to reboot after dx-group for group changes to take effect
```

### 📦 Step 1: Install Prerequisites
```bash
# just is usually pre-installed on Bluefin, but if not:
brew install just

# Verify installation
just --version
```

### ⚙️ Step 2: Run the Dotfiles Setup
```bash
# From the dotfiles directory (or any subdirectory):
just setup_dotfiles

# Or run with explicit path from anywhere:
just -f ~/dotfiles/justfile setup_dotfiles
```

### 🔄 One-Command Full Setup (Optional)
```bash
# Run prerequisites + dotfiles in sequence:
just setup_bluefin_prereqs && just setup_dotfiles
```

## 🧠 just Basics (For Beginners)

| Concept | Explanation |
|---------|-------------|
| `justfile` | A config file containing named command blocks ("recipes") |
| Recipe | A function-like block: `name:` followed by indented commands |
| Variable | `NAME := value` — evaluated before recipe runs |
| `{{VAR}}` | Interpolates variable into recipe body (substituted by just) |
| Shebang recipe | `#!/usr/bin/env bash` runs entire body in one shell |
| Idempotent | Running twice won't break things or duplicate work |

## 🔍 What This Setup Does

### `just setup_bluefin_prereqs`
1. ✅ Runs `ujust bluefin-cli` → Installs CLI tools & dev environment basics
2. ⚠️ Runs `ujust devmode` → Enables developer mode (**skipped on Bluefin LTS**)
3. ✅ Runs `ujust dx-group` → Adds user to developer groups for container access

### `just setup_dotfiles`
1. ✅ **Verifies** Homebrew is installed at `/home/linuxbrew/.linuxbrew`
2. 📦 **Clones/Pulls** this repo to `~/dotfiles`
3. 🍺 **Runs** `brew bundle` to install all CLI tools from `Brewfile`
4. 🔗 **Symlinks** `dot_*` files to their `~/.config` or `~` destinations
5. 🐚 **Installs** Oh-My-Zsh + `zsh-autosuggestions` + `zsh-syntax-highlighting`
6. 🪞 **Sets up** Atuin for shell history sync
7. 📋 **Displays** a completion summary with next steps

## 🛠️ Common Commands

```bash
# List available recipes
just --list

# Show recipe source code
just --show setup_dotfiles

# Run the main setup
just setup_dotfiles

# Run Bluefin prerequisites (first-time only)
just setup_bluefin_prereqs

# Dry-run (preview without executing)
just --dry-run setup_dotfiles

# Run with verbose bash tracing (debug mode)
just setup_dotfiles -- --verbose

# Run a different recipe (if you add more later)
just other_recipe
```

## 🔧 Customizing for Your Machine

### Add a New Dotfile
Edit the `link_file` calls in `justfile`:
```just
link_file "{{DOTFILES_DIR}}/dot_vimrc" "$HOME/.vimrc"
```

### Add a Package
Edit `Brew/Brewfile`, then re-run:
```bash
just setup_dotfiles
```

### Add a Zsh Plugin
Add to the `plugins=(...)` array in `justfile`:
```just
plugins=(
    "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "your-new-plugin:https://github.com/user/your-new-plugin.git"
)
```

### Change the Repo URL
Edit the `git clone` line in `justfile`:
```just
git clone --recursive https://github.com/YOU/your-dotfiles.git "{{DOTFILES_DIR}}"
```

### Add a New Recipe
Append to `justfile`:
```just
update_plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Updating Zsh plugins..."
    for plugin in {{ZSH_CUSTOM}}/plugins/*; do
        [[ -d "$plugin/.git" ]] && git -C "$plugin" pull --rebase -q
    done
    echo "✅ Plugins updated."
```
Then run with: `just update_plugins`

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| `just: No justfile found` | Run from `~/dotfiles` or use `-f ~/dotfiles/justfile` |
| `brew: command not found` | Add `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` to `~/.bashrc` or `~/.zprofile` |
| Symlink permission error | Ensure `~/dotfiles` is owned by you: `chown -R $USER:$USER ~/dotfiles` |
| Script stops halfway | Read the error — it's usually a missing file. Fix it and re-run; the script picks up where it left off. |
| Want to see commands before running | Use `--dry-run`: `just --dry-run setup_dotfiles` |
| Variable not substituting | Check spelling: `{{DOTFILES_DIR}}` not `{{DOTFILES_DIR}}` (no spaces inside `{{}}`) |
| `ujust devmode` fails on LTS | **This is expected!** Skip `devmode` on Bluefin LTS — it's already enabled. |
| Group changes not taking effect | Reboot or run `newgrp dx` to reload group membership |

## 🤝 Contributing & Maintenance

This setup is designed for **Bluefin Linux** (Fedora Silverblue base + Homebrew).
- All paths use `env("HOME")` for portability (`/var/home/salman` on Bluefin)
- No `sudo` required — everything stays in `$HOME`
- Fully transparent: every command is visible bash

## 📜 License
MIT © Salman
