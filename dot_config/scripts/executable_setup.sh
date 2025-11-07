#!/bin/bash
###############################################################################
# Fedora Workstation & Dotfiles Setup Script
# This script performs system configuration and application installation for
# a fresh Fedora Workstation installation, then sets up your dotfiles and 
# development environment. It is very verbose and uses ASCII art banners to
# clearly indicate each major step.
###############################################################################

# Make sure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

###############################################################################
# Utility Functions
###############################################################################

# Function to echo colored text for better readability
color_echo() {
    local color="$1"
    local text="$2"
    case "$color" in
        "red")     echo -e "\033[0;31m$text\033[0m" ;;
        "green")   echo -e "\033[0;32m$text\033[0m" ;;
        "yellow")  echo -e "\033[1;33m$text\033[0m" ;;
        "blue")    echo -e "\033[0;34m$text\033[0m" ;;
        *)         echo "$text" ;;
    esac
}

# Function to generate timestamps for log messages
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Function to log messages to a logfile (and stdout)
log_message() {
    local message="$1"
    echo "$(get_timestamp) - $message" | tee -a "$LOG_FILE"
}

# Function to handle errors – exit the script with an error message if needed.
handle_error() {
    local exit_code=$?
    local message="$1"
    if [ $exit_code -ne 0 ]; then
        color_echo "red" "ERROR: $message"
        exit $exit_code
    fi
}

# Function to prompt the user for a reboot
prompt_reboot() {
    sudo -u "$ACTUAL_USER" bash -c 'read -p "It is time to reboot the machine. Would you like to do it now? (y/n): " choice; [[ $choice == [yY] ]]'
    if [ $? -eq 0 ]; then
        color_echo "green" "Rebooting..."
        reboot
    else
        color_echo "red" "Reboot canceled. Please reboot later to finalize all changes."
    fi
}

# Function to backup a file before modifying it
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$file.bak"
        handle_error "Failed to backup $file"
        color_echo "green" "Backed up $file to $file.bak"
    fi
}

# Function to install a package if it is not already installed (for dotfiles section)
install_package() {
    echo "----------------------------------------"
    echo "Checking for package: $1"
    if ! rpm -q "$1" &>/dev/null; then
        echo "Package $1 not found. Installing..."
        dnf install -y "$1"
    else
        echo "Package $1 is already installed."
    fi
}

###############################################################################
# Variables & Initial Setup
###############################################################################

# Determine the actual (non-root) user and home directory
ACTUAL_USER=$SUDO_USER
ACTUAL_HOME=$(eval echo "~$SUDO_USER")
USER_HOME="$ACTUAL_HOME"   # Use this variable in the dotfiles section

LOG_FILE="/var/log/fedora_things_to_do.log"
INITIAL_DIR=$(pwd)

###############################################################################
# Section 1: Fedora Workstation Setup
###############################################################################

cat << "EOF"
╔═════════════════════════════════════════════════════════════════════════════╗
║                                                                             ║
║   ░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░▀█▀░█▀█░▀█▀░▀█▀░█▀█░█▀█░   ║
║   ░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░░█░░█▀█░░█░░░█░░█░█░█░█░   ║
║   ░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░░▀░▀░░▀░░▀▀▀░▀▀▀░▀░▀░   ║
║   ░░░░░░░░░░░░▀█▀░█░█░▀█▀░█▀█░█▀▀░█▀▀░░░▀█▀░█▀█░░░█▀▄░█▀█░█░░░░░░░░░░░░░░   ║
║   ░░░░░░░░░░░░░█░░█▀█░░█░░█░█░█░█░▀▀█░░░░█░░█░█░░░█░█░█░█░▀░░░░░░░░░░░░░░   ║
║   ░░░░░░░░░░░░░▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░░░░▀░░▀▀▀░░░▀▀░░▀▀▀░▀░░░░░░░░░░░░░░   ║
║                                                                             ║
╚═════════════════════════════════════════════════════════════════════════════╝
EOF

echo ""
echo "Fedora Workstation Setup – ver. 25.03"
echo "This section will perform system upgrade, configuration, and install a variety of applications."
echo "Don't run this script unless you trust its source and understand what it does."
echo ""
read -p "Press Enter to continue or CTRL+C to cancel..."

# -------------------------------
# System Upgrade & Configuration
# -------------------------------

color_echo "blue" "Performing system upgrade... This may take a while..."
dnf upgrade -y
handle_error "System upgrade failed!"

# Configure DNF Package Manager for faster downloads
color_echo "yellow" "Configuring DNF Package Manager..."
backup_file "/etc/dnf/dnf.conf"
echo "max_parallel_downloads=10" | tee -a /etc/dnf/dnf.conf > /dev/null
dnf -y install dnf-plugins-core

# Enable automatic system updates
color_echo "yellow" "Enabling DNF autoupdate..."
dnf install dnf-automatic -y
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer

# Configure Flatpak: Replace Fedora repo with Flathub
color_echo "yellow" "Replacing Fedora Flatpak Repo with Flathub..."
dnf install -y flatpak
flatpak remote-delete fedora --force || true
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak repair
flatpak update

# Firmware updates
color_echo "yellow" "Checking for firmware updates..."
fwupdmgr refresh --force
fwupdmgr get-updates
fwupdmgr update -y

# Enable RPM Fusion repositories
color_echo "yellow" "Enabling RPM Fusion repositories..."
dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf group update core -y

# Multimedia Codecs Installation
color_echo "yellow" "Installing multimedia codecs..."
dnf swap ffmpeg-free ffmpeg --allowerasing -y
dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
dnf update @sound-and-video -y

# Hardware Accelerated Codecs for Intel and AMD
color_echo "yellow" "Installing Intel Hardware Accelerated Codecs..."
dnf -y install intel-media-driver
color_echo "yellow" "Installing AMD Hardware Accelerated Codecs..."
dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y
dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y

# Virtualization Tools
color_echo "yellow" "Installing virtualization tools..."
dnf install -y @virtualization

# Configure power settings (disable sleep/hibernate)
color_echo "yellow" "Configuring power settings..."
sudo -u "$ACTUAL_USER" gsettings set org.gnome.desktop.session idle-delay 0
sudo -u "$ACTUAL_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
sudo -u "$ACTUAL_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
sudo -u "$ACTUAL_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
sudo -u "$ACTUAL_USER" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
sudo -u "$ACTUAL_USER" gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'

# -------------------------------
# Application Installation
# -------------------------------

# Essential applications
color_echo "yellow" "Installing essential applications..."
dnf install -y btop tmux fastfetch unzip unrar git wget curl gnome-tweaks syncthing
color_echo "green" "Essential applications installed successfully."

# Internet & Communication apps via Flatpak and DNF
color_echo "yellow" "Installing LibreWolf via Flatpak..."
flatpak install -y flathub io.gitlab.librewolf-community
color_echo "green" "LibreWolf installed successfully."
color_echo "yellow" "Installing Thunderbird via DNF..."
dnf install -y thunderbird
color_echo "green" "Thunderbird installed successfully."
color_echo "yellow" "Installing Discord via Flatpak..."
flatpak install -y flathub com.discordapp.Discord
color_echo "green" "Discord installed successfully."
color_echo "yellow" "Installing Element via Flatpak..."
flatpak install -y flathub im.riot.Riot
color_echo "green" "Element installed successfully."
color_echo "yellow" "Installing Telegram Desktop via Flatpak..."
flatpak install -y flathub org.telegram.desktop
color_echo "green" "Telegram Desktop installed successfully."
color_echo "yellow" "Installing Signal Desktop via Flatpak..."
flatpak install -y flathub org.signal.Signal
color_echo "green" "Signal Desktop installed successfully."
color_echo "yellow" "Installing Whatsie via Flatpak..."
flatpak install -y flathub com.ktechpit.whatsie
color_echo "green" "Whatsie installed successfully."

# Office Productivity Apps
color_echo "yellow" "Installing LibreOffice via Flatpak..."
dnf remove -y libreoffice*
flatpak install -y flathub org.libreoffice.LibreOffice
flatpak install -y --reinstall org.freedesktop.Platform.Locale/x86_64/24.08
flatpak install -y --reinstall org.libreoffice.LibreOffice.Locale
color_echo "green" "LibreOffice installed successfully."
color_echo "yellow" "Installing WPS Office via Flatpak..."
flatpak install -y flathub com.wps.Office
color_echo "green" "WPS Office installed successfully."
color_echo "yellow" "Installing Obsidian via Flatpak..."
flatpak install -y flathub md.obsidian.Obsidian
color_echo "green" "Obsidian installed successfully."
color_echo "yellow" "Installing Bitwarden via Flatpak..."
flatpak install -y flathub com.bitwarden.desktop
color_echo "green" "Bitwarden installed successfully."
color_echo "yellow" "Installing KeePassXC via DNF..."
dnf install -y keepassxc
color_echo "green" "KeePassXC installed successfully."

# Coding & DevOps Tools
color_echo "yellow" "Installing Visual Studio Code..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat << EOF | tee /etc/yum.repos.d/vscode.repo > /dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf check-update
dnf install -y code
color_echo "green" "Visual Studio Code installed successfully."
color_echo "yellow" "Installing GitHub Desktop via Flatpak..."
flatpak install -y flathub io.github.shiftey.Desktop
color_echo "green" "GitHub Desktop installed successfully."
color_echo "yellow" "Installing Ansible via DNF..."
dnf install -y ansible
color_echo "green" "Ansible installed successfully."
color_echo "yellow" "Installing Docker and dependencies..."
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine --noautoremove
dnf -y install dnf-plugins-core
if command -v dnf4 &>/dev/null; then
  dnf4 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
else
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
fi
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
systemctl enable --now containerd
groupadd docker 2>/dev/null || true
usermod -aG docker "$ACTUAL_USER"
rm -rf "$ACTUAL_HOME/.docker"
color_echo "green" "Docker installed successfully. (Log out/in may be required for group changes.)"
color_echo "yellow" "Installing Podman via DNF..."
dnf install -y podman
color_echo "green" "Podman installed successfully."
color_echo "yellow" "Installing Tabby terminal..."
wget https://github.com/Eugeny/tabby/releases/download/v1.0.221/tabby-1.0.221-linux-x64.rpm
dnf install -y ./tabby-1.0.221-linux-x64.rpm
rm -f ./tabby-1.0.221-linux-x64.rpm
color_echo "green" "Tabby installed successfully."
color_echo "yellow" "Installing VeraCrypt..."
wget https://launchpad.net/veracrypt/trunk/1.26.20/+download/veracrypt-1.26.20-Fedora-40-x86_64.rpm
dnf install -y ./veracrypt-1.26.20-Fedora-40-x86_64.rpm
rm -f ./veracrypt-1.26.20-Fedora-40-x86_64.rpm
color_echo "green" "VeraCrypt installed successfully."

# Zsh and Oh My Zsh
color_echo "yellow" "Installing Zsh and setting up Oh My Zsh..."
dnf install -y zsh
sudo -u "$ACTUAL_USER" sh -c 'RUNZSH=no $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) "" --unattended'
chsh -s "$(which zsh)" "$ACTUAL_USER"
sudo -u "$ACTUAL_USER" bash << 'EOF'
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/marlonrichert/zsh-autocomplete.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(dnf aliases genpass git zsh-autosuggestions zsh-autocomplete zsh-history-substring-search z zsh-syntax-highlighting)/' "$HOME/.zshrc"
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="jonathan"/' "$HOME/.zshrc"
EOF
color_echo "green" "Zsh and Oh My Zsh installed successfully."

# Miniconda installation
color_echo "yellow" "Installing Miniconda..."
sudo -u "$ACTUAL_USER" bash << EOF
mkdir -p "$HOME/.miniconda3"
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$HOME/.miniconda3/miniconda.sh"
bash "$HOME/.miniconda3/miniconda.sh" -b -u -p "$HOME/.miniconda3"
rm -rf "$HOME/.miniconda3/miniconda.sh"
"$HOME/.miniconda3/bin/conda" init bash
"$HOME/.miniconda3/bin/conda" init zsh
EOF
color_echo "green" "Miniconda installed successfully."

# Media & Graphics Applications
color_echo "yellow" "Installing VLC, GIMP, Inkscape, Krita, Blender, OBS Studio, Kdenlive and FreeTube..."
dnf install -y vlc gimp inkscape krita blender obs-studio kdenlive
flatpak install -y flathub io.freetubeapp.FreeTube
color_echo "green" "Media & Graphics applications installed successfully."

# Remote Networking
color_echo "yellow" "Installing Mullvad VPN..."
if command -v dnf4 &>/dev/null; then
  dnf4 config-manager --add-repo https://repository.mullvad.net/rpm/stable/mullvad.repo
else
  dnf config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo
fi
dnf install -y mullvad-vpn
color_echo "green" "Mullvad VPN installed successfully."

# File Sharing & Download Applications
color_echo "yellow" "Installing Video Downloader via Flatpak..."
flatpak install -y flathub com.github.unrud.VideoDownloader
color_echo "green" "Video Downloader installed successfully."

# System Tools
color_echo "yellow" "Installing Mission Center, Flatseal, Extension Manager, Bottles, PeaZip, Deja Dup, and Pika Backup via Flatpak..."
flatpak install -y flathub io.missioncenter.MissionCenter
flatpak install -y flathub com.github.tchx84.Flatseal
flatpak install -y flathub com.mattjakeman.ExtensionManager
flatpak install -y flathub com.usebottles.bottles
flatpak install -y flathub io.github.peazip.PeaZip
flatpak install -y flathub org.gnome.DejaDup
flatpak install -y flathub org.gnome.World.PikaBackup
color_echo "green" "System Tools installed successfully."

# Customizations: Fonts
color_echo "yellow" "Installing Microsoft Core Fonts..."
dnf install -y curl cabextract xorg-x11-font-utils fontconfig
rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
color_echo "green" "Microsoft Core Fonts installed successfully."
color_echo "yellow" "Installing Google Fonts..."
wget -O /tmp/google-fonts.zip https://github.com/google/fonts/archive/main.zip
mkdir -p "$ACTUAL_HOME/.local/share/fonts/google"
unzip /tmp/google-fonts.zip -d "$ACTUAL_HOME/.local/share/fonts/google"
rm -f /tmp/google-fonts.zip
fc-cache -fv
color_echo "green" "Google Fonts installed successfully."
color_echo "yellow" "Installing Adobe Fonts..."
mkdir -p "$ACTUAL_HOME/.local/share/fonts/adobe-fonts"
git clone --depth 1 https://github.com/adobe-fonts/source-sans.git "$ACTUAL_HOME/.local/share/fonts/adobe-fonts/source-sans"
git clone --depth 1 https://github.com/adobe-fonts/source-serif.git "$ACTUAL_HOME/.local/share/fonts/adobe-fonts/source-serif"
git clone --depth 1 https://github.com/adobe-fonts/source-code-pro.git "$ACTUAL_HOME/.local/share/fonts/adobe-fonts/source-code-pro"
fc-cache -f
color_echo "green" "Adobe Fonts installed successfully."

color_echo "green" "Fedora Workstation setup completed successfully!"

###############################################################################
# Section 2: Dotfiles & Development Environment Setup
###############################################################################

cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           D O T F I L E S   &   D E V   S E T U P           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""
echo "Starting Dotfiles Setup"
DOTFILES_DIR="$USER_HOME/Dotfiles"
echo "Dotfiles directory: $DOTFILES_DIR"
echo "----------------------------------------"

# Create symlinks for configuration files

echo "Creating symlinks for configuration files..."

# Zsh configuration
echo "Linking zsh config: $DOTFILES_DIR/zsh/.zshrc -> $USER_HOME/.zshrc"
ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$USER_HOME/.zshrc"
echo "Linking zsh plugins list: $DOTFILES_DIR/zsh/plugins/.zsh_plugins.txt -> $USER_HOME/.zsh_plugins.txt"
ln -sf "$DOTFILES_DIR/zsh/plugins/.zsh_plugins.txt" "$USER_HOME/.zsh_plugins.txt"

# Helix configuration (placed in ~/.config/helix)
echo "Ensuring ~/.config directory exists..."
mkdir -p "$USER_HOME/.config"
if [ -e "$USER_HOME/.config/helix" ]; then
    echo "Existing Helix config found. Removing it..."
    rm -rf "$USER_HOME/.config/helix"
fi
echo "Linking Helix config: $DOTFILES_DIR/helix -> $USER_HOME/.config/helix"
ln -sf "$DOTFILES_DIR/helix" "$USER_HOME/.config/helix"

# Git configuration
if [ -f "$DOTFILES_DIR/git/.gitconfig" ]; then
    echo "Checking for existing Git config at $USER_HOME/.gitconfig..."
    if [ -e "$USER_HOME/.gitconfig" ]; then
        echo "Existing Git config found. Removing it..."
        rm -f "$USER_HOME/.gitconfig"
    fi
    echo "Linking Git config file: $DOTFILES_DIR/git/.gitconfig -> $USER_HOME/.gitconfig"
    ln -sf "$DOTFILES_DIR/git/.gitconfig" "$USER_HOME/.gitconfig"
else
    echo "No .gitconfig file found in $DOTFILES_DIR/git."
    echo "Linking entire Git directory to ~/.config/git"
    mkdir -p "$USER_HOME/.config"
    if [ -e "$USER_HOME/.config/git" ]; then
        echo "Existing Git config directory found. Removing it..."
        rm -rf "$USER_HOME/.config/git"
    fi
    ln -sf "$DOTFILES_DIR/git" "$USER_HOME/.config/git"
fi

# -------------------------------
# Install additional system packages
# -------------------------------

echo "Installing required system packages for development..."
packages=(
    zsh
    fzf
    ripgrep
    fd-find
    bat
    duf
    hyperfine
    zoxide
    gcc-c++
    cmake         # For building native code
    cascadia-mono-nf-fonts
    intel-one-mono-fonts
    gitui
    git-delta
    docker
    btop
)

for pkg in "${packages[@]}"; do
    install_package "$pkg"
done

echo "Installing development tools group (may prompt for confirmation)..."
dnf group install -y development-tools

# -------------------------------
# Install Rust via rustup (if not installed)
# -------------------------------

if ! command -v rustc &>/dev/null; then
    echo "Rust not found. Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo "Rust installed. Please ensure your shell sources the cargo environment (you might need to restart your terminal)."
else
    echo "Rust is already installed."
fi

# -------------------------------
# Install Rust tools via cargo
# -------------------------------

echo "Installing Rust tools via cargo (atuin, eza, starship)..."
cargo install --locked atuin eza starship

# Uncomment the following if you want to install 'bottom' via cargo:
# cargo install bottom

# -------------------------------
# Setup Antidote (Zsh plugin manager)
# -------------------------------

echo "Setting up Antidote (Zsh plugin manager)..."
if [ ! -d "$USER_HOME/.antidote" ]; then
    echo "Antidote not found. Cloning into ~/.antidote..."
    sudo -u "$ACTUAL_USER" git clone --depth=1 https://github.com/mattmc3/antidote.git "$USER_HOME/.antidote"
else
    echo "Antidote is already installed."
fi

if [ -f "$USER_HOME/.zsh_plugins.txt" ]; then
    echo "Installing Antidote plugins from $USER_HOME/.zsh_plugins.txt..."
    sudo -u "$ACTUAL_USER" zsh -c 'source "$HOME/.antidote/antidote.zsh" && antidote bundle < "$HOME/.zsh_plugins.txt" > "$HOME/.zsh_plugins.zsh"'
else
    echo "Warning: $USER_HOME/.zsh_plugins.txt not found. Skipping plugin installation."
fi

# -------------------------------
# Set default shell to Zsh for the user
# -------------------------------

echo "Setting default shell to zsh if not already set..."
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" "$ACTUAL_USER"
    echo "Default shell changed to zsh."
else
    echo "Default shell is already zsh."
fi

# Initialize zoxide for the current session
echo "Initializing zoxide..."
eval "$(zoxide init zsh)"

echo ""
echo "========================================"
echo "Dotfiles and development environment setup complete!"
echo "Please restart your terminal or run: exec zsh"
echo "========================================"

###############################################################################
# Final Steps
###############################################################################

# Ensure we're not in a dangerous directory before finishing
cd /tmp || cd "$USER_HOME" || cd /

cat << "EOF"
╔═════════════════════════════════════════════════════════════════════════╗
║                                                                         ║
║   ░█░█░█▀▀░█░░░█▀▀░█▀█░█▄█░█▀▀░░░▀█▀░█▀█░░░█▀▀░█▀▀░█▀▄░█▀█░█▀▄░█▀█░█░   ║
║   ░█▄█░█▀▀░█░░░█░░░█░█░█░█░█▀▀░░░░█░░█░█░░░█▀▀░█▀▀░█░█░█░█░█▀▄░█▀█░▀░   ║
║   ░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░░▀░░▀▀▀░░░▀░░░▀▀▀░▀▀░░▀▀▀░▀░▀░▀░▀░▀░   ║
║                                                                         ║
╚═════════════════════════════════════════════════════════════════════════╝
EOF

# Prompt for reboot if desired
prompt_reboot

