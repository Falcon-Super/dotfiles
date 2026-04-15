# 🐧 Bluefin Linux Dotfiles (just Edition)

This repository manages my personal development environment on **Bluefin Linux** using [`just`](https://github.com/casey/just), a simple, transparent command runner. It complements Bluefin's cloud-native workflow by handling shell configuration, CLI tooling via Homebrew, and local dotfiles — while keeping the host OS immutable and clean.

> 💡 **Bluefin Philosophy**: Development happens in containers, not on the host. This repo configures *your shell and local tooling* — not system packages. For project dependencies, use [devcontainers](https://containers.dev), [mise](https://mise.jdx.dev), or `Brewfile`s in version control.

## 🎯 Philosophy
- **Minimal**: One `justfile` does everything
- **Transparent**: Every command is visible bash — no hidden magic
- **Idempotent**: Safe to run 1 or 100 times
- **Bluefin-native**: Works with `/var/home`, Linuxbrew, and immutable OS
- **Container-first**: Local config only — project deps belong in `devcontainer.json` or `mise.toml`

## 📁 Repository Structure
```
dotfiles/
├── README.md              ← You are here
├── justfile               ← Main setup script (run with `just`)
├── Brew/
│   └── Brewfile           ← Homebrew CLI tools (global, not project-specific)
├── dot_config/            ← Config files for ~/.config/
│   ├── fastfetch/         # System info display
│   ├── ghostty/           # Terminal emulator config
│   ├── helix/             # Modern modal editor
│   └── scripts/           # Utility scripts
├── dot_gitconfig          ← ~/.gitconfig source
└── dot_zshrc              ← ~/.zshrc source (Oh-My-Zsh + plugins)
```

## 🚀 Quick Start

### 🔧 Step 0: Enable Bluefin Developer Mode (FIRST TIME ONLY)
> ⚠️ **Required for container tooling, KVM, and developer groups**

```bash
# 1. Enable developer mode (adds dev tooling to your user environment)
ujust devmode

# 2. Add your user to developer groups (for podman/docker/KVM access)
#    ⚠️ SKIP this step if you're on Bluefin LTS — groups are pre-configured
ujust dx-group

# 3. Reboot to apply group changes
reboot
```

### 📦 Step 1: Install `just` (if not present)
```bash
# just is usually pre-installed on Bluefin, but verify:
just --version

# If missing, install via Homebrew (Bluefin's recommended CLI package manager)
brew install just
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
3. 🍺 **Runs** `brew bundle` to install global CLI tools from `Brewfile`
4. 🔗 **Symlinks** `dot_*` files to their `~/.config` or `~` destinations
5. 🐚 **Installs** Oh-My-Zsh + `zsh-autosuggestions` + `zsh-syntax-highlighting`
6. 🪞 **Sets up** Atuin for shell history sync
7. 📋 **Displays** a completion summary with next steps

## 🌐 Bluefin Workflow Integration

This dotfiles setup is designed to **complement**, not replace, Bluefin's cloud-native development model:

| Use Case | Recommended Tool | This Repo's Role |
|----------|-----------------|------------------|
| **Project dependencies** | `devcontainer.json`, `mise.toml`, `Brewfile` in repo | ❌ Not handled here |
| **Global CLI tools** | Homebrew (`brew install`) | ✅ `Brew/Brewfile` manages these |
| **Shell config** | Zsh/Fish config files | ✅ `dot_zshrc`, plugins, Atuin |
| **Editor config** | VSCode settings, Helix config | ✅ `dot_config/helix/`, `ghostty/` |
| **Container runtimes** | Podman, Docker, Incus | ✅ Enables via `dx-group` (prereqs) |
| **Pet containers** | Distrobox via DistroShelf | ✅ Shell integration for seamless use |

### 🐳 Recommended Project Setup
For new projects, declare dependencies in version control instead of relying on global installs:

```bash
# Example: devcontainer for a Node.js project
.devcontainer/
├── devcontainer.json
└── Dockerfile

# Example: mise for language/tool version management
mise.toml
```

Then use:
```bash
# VSCode: Open folder → "Reopen in Container"
# CLI: distrobox enter my-project-container
```

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

### Add a Global CLI Tool
Edit `Brew/Brewfile`, then re-run:
```bash
just setup_dotfiles
```

> ⚠️ **Prefer project-local tools**: For project-specific tools, add them to your repo's `Brewfile`, `mise.toml`, or `devcontainer.json` instead.

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
| Containers not accessible | Ensure you ran `ujust dx-group` and rebooted (non-LTS only) |

## 🤝 Contributing & Maintenance

This setup is designed for **Bluefin Linux** (Fedora Silverblue base + Homebrew).
- All paths use `env("HOME")` for portability (`/var/home/salman` on Bluefin)
- No `sudo` required — everything stays in `$HOME`
- Fully transparent: every command is visible bash
- **Host-immutable friendly**: No system modifications, only user-space config

### 🔄 Updating This Setup
```bash
# Pull latest changes and re-apply
git -C ~/dotfiles pull --rebase
just setup_dotfiles
```

### 🧹 Cleaning Up
```bash
# Remove symlinks (backup files are created automatically)
rm ~/.zshrc ~/.gitconfig ~/.config/helix/config.toml  # etc.
# Then re-run setup to restore
just setup_dotfiles
```

## 📚 Further Reading
- [Bluefin Documentation](https://docs.projectbluefin.io)
- [Cloud Native Development Guide](https://docs.projectbluefin.io/development)
- [Dev Containers Specification](https://containers.dev)
- [mise: Version Manager](https://mise.jdx.dev)
- [just Command Runner](https://github.com/casey/just)

## 📜 License
MIT © Salman
