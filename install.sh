#!/usr/bin/env bash
#
# Debian 13 (Trixie) Sway Desktop Post-Install Automation Script
#
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_URL="https://github.com/brianjag/dotfiles"
TAR_URL="https://github.com/brianjag/dotfiles/archive/refs/heads/main.tar.gz"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# Color output helpers
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}${BOLD}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}${BOLD}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}${BOLD}[ERROR]${NC} $1"; }

# Ensure we are not running the entire script as root
check_user() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "Do not run this script directly as root. Run as your normal user."
        log_info "The script will use 'sudo' for commands requiring elevated privileges."
        exit 1
    fi
}

bootstrap_dotfiles() {
    # If the script is already running from a local clone containing packages
    if [ -f "$DIR/packages" ]; then
        DOTFILES_DIR="$DIR"
        return 0
    fi

    log_info "Running via remote pipe. Bootstrapping dotfiles into $DOTFILES_DIR..."
    mkdir -p "$DOTFILES_DIR"

    if command -v curl &>/dev/null; then
        curl -fsSL "$TAR_URL" | tar -xz --strip-components=1 -C "$DOTFILES_DIR"
    elif command -v wget &>/dev/null; then
        wget -qO- "$TAR_URL" | tar -xz --strip-components=1 -C "$DOTFILES_DIR"
    else
        log_error "Neither curl nor wget is available to download dotfiles."
        exit 1
    fi
    log_success "Dotfiles repository unpacked into $DOTFILES_DIR."
}

setup_git_repo() {
    if [ ! -d "$DOTFILES_DIR/.git" ] && command -v git &>/dev/null; then
        log_info "Setting up git remote tracking in $DOTFILES_DIR..."
        (
            cd "$DOTFILES_DIR"
            git init -b main
            git remote add origin "$REPO_URL.git"
            git fetch origin main 2>/dev/null || true
            git reset --mixed origin/main 2>/dev/null || true
        ) 2>/dev/null || true
        log_success "Git tracking configured."
    fi
}

install_apt() {
    log_info "Updating package lists..."
    sudo apt update

    log_info "Installing APT packages from manifest..."
    if [ -f "$DOTFILES_DIR/packages" ]; then
        packages=$(grep -v '^#' "$DOTFILES_DIR/packages" | grep -v '^$' | tr '\n' ' ')
        sudo apt install -y --no-install-recommends $packages
    else
        log_error "packages file not found in $DOTFILES_DIR"
        exit 1
    fi

    log_info "Enabling essential system services..."
    sudo systemctl enable --now mariadb.service || true
    sudo systemctl enable --now tlp.service || true
    sudo systemctl enable --now bluetooth.service || true
    sudo systemctl enable --now NetworkManager.service || true

    setup_git_repo
    log_success "APT packages and services configured."
}

install_zsh() {
    log_info "Checking oh-my-zsh installation..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing oh-my-zsh (unattended)..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions plugin..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi

    if [ -f "$HOME/.zshrc" ]; then
        if grep -q "plugins=(.*zsh-autosuggestions.*)" "$HOME/.zshrc"; then
            log_info "zsh-autosuggestions already configured in ~/.zshrc"
        else
            sed -i 's/plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions)/' "$HOME/.zshrc" || true
        fi
    fi

    log_success "Zsh and plugins ready."
}

install_flatpaks() {
    log_info "Configuring Flatpak & Flathub..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    if [ -f "$DOTFILES_DIR/flatpaks" ]; then
        log_info "Installing Flatpak applications..."
        while IFS= read -r app || [ -n "$app" ]; do
            [[ "$app" =~ ^#.*$ || -z "$app" ]] && continue
            echo "-> Installing: $app"
            flatpak install -y --noninteractive flathub "$app" || log_warn "Failed installing $app"
        done < "$DOTFILES_DIR/flatpaks"
    fi
    log_success "Flatpak applications installed."
}

install_cli_tools() {
    log_info "Installing CLI tools and developer runtimes..."

    # 1. nvm + Node LTS
    if [ ! -d "$HOME/.nvm" ]; then
        log_info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    if command -v nvm &>/dev/null; then
        log_info "Installing Node.js LTS via nvm..."
        nvm install --lts || true
    fi

    # 2. AWS CLI v2
    if ! command -v aws &>/dev/null; then
        log_info "Installing AWS CLI v2..."
        TMP_AWS=$(mktemp -d)
        curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMP_AWS/awscliv2.zip"
        unzip -qo "$TMP_AWS/awscliv2.zip" -d "$TMP_AWS"
        sudo "$TMP_AWS/aws/install" --update
        rm -rf "$TMP_AWS"
    fi

    # 3. GitHub CLI (gh)
    if ! command -v gh &>/dev/null; then
        log_info "Configuring GitHub CLI official repository..."
        sudo mkdir -p -m 755 /etc/apt/keyrings
        wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update && sudo apt install -y gh
    fi

    # gh handles git credential management; no separate credential manager needed
    if command -v gh &>/dev/null; then
        gh auth setup-git 2>/dev/null || true
    fi

    # 4. Claude Code
    if ! command -v claude &>/dev/null; then
        log_info "Installing Claude Code CLI..."
        curl -fsSL https://claude.ai/install.sh | bash || true
    fi

    # 5. OpenCode
    if ! command -v opencode &>/dev/null; then
        log_info "Installing OpenCode..."
        curl -fsSL https://opencode.ai/install | bash || true
    fi

    # 6. Google Antigravity CLI (agy)
    if ! command -v agy &>/dev/null; then
        log_info "Installing Google Antigravity CLI (agy)..."
        curl -fsSL https://antigravity.google/cli/install.sh | bash || true
    fi

    # 7. Ollama
    if ! command -v ollama &>/dev/null; then
        log_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh || true
    fi

    # 8. Python CLI tools (yt-dlp, buku, beets) via pipx
    log_info "Ensuring pipx path is configured..."
    pipx ensurepath || true

    log_info "Installing Python tools via pipx (yt-dlp, buku, beets)..."
    for tool in yt-dlp buku beets; do
        if ! command -v "$tool" &>/dev/null; then
            pipx install "$tool" || log_warn "Failed installing $tool via pipx"
        else
            pipx upgrade "$tool" || true
        fi
    done

    log_success "CLI tools installed."
}

install_desktop_apps() {
    log_info "Installing manual desktop applications from official sources..."

    # Google Chrome
    if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null; then
        log_info "Installing Google Chrome..."
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$TMP_DEB"
        sudo apt install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
    fi

    # LibreWolf
    if ! command -v librewolf &>/dev/null; then
        log_info "Configuring LibreWolf repository..."
        curl -fsSL https://deb.librewolf.net/keyring.gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/librewolf.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/librewolf.gpg] http://deb.librewolf.net trixie main" | sudo tee /etc/apt/sources.list.d/librewolf.list
        sudo apt update && sudo apt install -y librewolf || log_warn "LibreWolf install failed"
    fi

    # Calibre
    if ! command -v calibre &>/dev/null; then
        log_info "Installing Calibre via official installer..."
        sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin || true
    fi

    # Obsidian
    if ! command -v obsidian &>/dev/null; then
        log_info "Installing Obsidian..."
        OBS_URL=$(curl -sL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r '.assets[] | select(.name | endswith(".deb") and (contains("arm") | not)) | .browser_download_url' | head -n 1)
        if [ -n "$OBS_URL" ] && [ "$OBS_URL" != "null" ]; then
            TMP_DEB=$(mktemp --suffix=.deb)
            curl -sSL "$OBS_URL" -o "$TMP_DEB"
            sudo apt install -y "$TMP_DEB"
            rm -f "$TMP_DEB"
        fi
    fi

    # Beekeeper Studio
    if ! command -v beekeeper-studio &>/dev/null; then
        log_info "Configuring Beekeeper Studio repository..."
        curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/beekeeper.gpg
        echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" | sudo tee /etc/apt/sources.list.d/beekeeper-studio.list
        sudo apt update && sudo apt install -y beekeeper-studio || log_warn "Beekeeper Studio install failed"
    fi

    # Zoom
    if ! command -v zoom &>/dev/null; then
        log_info "Installing Zoom Workplace..."
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -sSL https://zoom.us/client/latest/zoom_amd64.deb -o "$TMP_DEB"
        sudo apt install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
    fi

    # OnlyOffice
    if ! command -v onlyoffice-desktopeditors &>/dev/null; then
        log_info "Installing OnlyOffice Desktop Editors..."
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -sSL https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb -o "$TMP_DEB"
        sudo apt install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
    fi

    # JetBrains Toolbox (AppImage)
    if [ ! -f "$HOME/.local/bin/jetbrains-toolbox" ]; then
        log_info "Installing JetBrains Toolbox AppImage..."
        mkdir -p "$HOME/.local/bin"
        TB_URL=$(curl -sL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' | jq -r '.TBA[0].downloads.linux.link')
        if [ -n "$TB_URL" ] && [ "$TB_URL" != "null" ]; then
            TB_TAR=$(mktemp --suffix=.tar.gz)
            curl -sSL "$TB_URL" -o "$TB_TAR"
            TB_TMP=$(mktemp -d)
            tar -xzf "$TB_TAR" -C "$TB_TMP"
            TB_BIN=$(find "$TB_TMP" -name "jetbrains-toolbox" -type f | head -n 1)
            if [ -f "$TB_BIN" ]; then
                cp "$TB_BIN" "$HOME/.local/bin/jetbrains-toolbox"
                chmod +x "$HOME/.local/bin/jetbrains-toolbox"
            fi
            rm -rf "$TB_TAR" "$TB_TMP"
        fi
    fi

    # RustDesk
    if ! command -v rustdesk &>/dev/null; then
        log_info "Installing RustDesk..."
        RD_URL=$(curl -sL https://api.github.com/repos/rustdesk/rustdesk/releases/latest | jq -r '.assets[] | select(.name | match("x86_64\\.deb$")) | .browser_download_url' | head -n 1)
        if [ -n "$RD_URL" ] && [ "$RD_URL" != "null" ]; then
            TMP_DEB=$(mktemp --suffix=.deb)
            curl -sSL "$RD_URL" -o "$TMP_DEB"
            sudo apt install -y "$TMP_DEB"
            rm -f "$TMP_DEB"
        fi
    fi

    # VS Code
    if ! command -v code &>/dev/null; then
        log_info "Installing Visual Studio Code..."
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -sSL 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64' -o "$TMP_DEB"
        sudo apt install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
    fi

    # Microsoft Edge
    if ! command -v microsoft-edge &>/dev/null && ! command -v microsoft-edge-stable &>/dev/null; then
        log_info "Installing Microsoft Edge..."
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -sSL 'https://go.microsoft.com/fwlink?linkid=2149051' -o "$TMP_DEB"
        sudo apt install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
    fi

    # Dropbox
    if ! dpkg -s dropbox &>/dev/null; then
        log_info "Installing Dropbox..."
        TMP_DEB=$(mktemp --suffix=.deb)
        curl -sSL 'https://linux.dropbox.com/packages/debian/dropbox_2020.03.04_amd64.deb' -o "$TMP_DEB"
        sudo apt install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
    fi

    # nwg-dock
    # Not packaged in Trixie (only sid/forky), so install the pinned Debian
    # build directly. All of its dependencies (libgtk-3-0t64, libglib2.0-0t64,
    # libgtk-layer-shell0, ...) are available in Trixie. If it ever lands in
    # Trixie or backports, move it back to the 'packages' manifest.
    if ! command -v nwg-dock &>/dev/null; then
        log_info "Installing nwg-dock (not in Trixie repositories)..."
        NWG_DEB=$(mktemp --suffix=.deb)
        if curl -fsSL "https://deb.debian.org/debian/pool/main/n/nwg-dock/nwg-dock_0.4.3-1_amd64.deb" -o "$NWG_DEB"; then
            sudo apt install -y "$NWG_DEB" || log_warn "nwg-dock dependencies not satisfied"
        else
            log_warn "Could not download nwg-dock"
        fi
        rm -f "$NWG_DEB"
    fi

    log_success "Desktop applications installed."
}

install_dotfiles() {
    log_info "Creating symlinks for Sway desktop and user dotfiles..."
    mkdir -p "$HOME/.config" \
             "$HOME/.local/share/backgrounds" \
             "$HOME/.local/bin"

    # Helper function to create clean symlinks (removing old targets/stale links)
    link_target() {
        local src="$1"
        local dest="$2"
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
                log_info "Already linked: $dest -> $src"
                return 0
            fi
            rm -rf "$dest"
        fi
        mkdir -p "$(dirname "$dest")"
        ln -s "$src" "$dest"
        log_info "Linked: $dest -> $src"
    }

    # Wayland Desktop Configurations
    [ -d "$DOTFILES_DIR/.sway" ] && link_target "$DOTFILES_DIR/.sway" "$HOME/.config/sway"
    [ -d "$DOTFILES_DIR/waybar" ] && link_target "$DOTFILES_DIR/waybar" "$HOME/.config/waybar"
    [ -d "$DOTFILES_DIR/mako" ] && link_target "$DOTFILES_DIR/mako" "$HOME/.config/mako"
    [ -d "$DOTFILES_DIR/wofi" ] && link_target "$DOTFILES_DIR/wofi" "$HOME/.config/wofi"

    # Wallpaper
    if [ -f "$DOTFILES_DIR/wallpaper.jpg" ]; then
        link_target "$DOTFILES_DIR/wallpaper.jpg" "$HOME/.local/share/backgrounds/wallpaper.jpg"
    fi

    # Terminal and Editor configs
    [ -f "$DOTFILES_DIR/.alacritty.toml" ] && link_target "$DOTFILES_DIR/.alacritty.toml" "$HOME/.alacritty.toml"
    [ -d "$DOTFILES_DIR/.mlterm" ] && link_target "$DOTFILES_DIR/.mlterm" "$HOME/.mlterm"
    [ -f "$DOTFILES_DIR/.vimrc" ] && link_target "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"

    # Helper scripts
    [ -f "$DOTFILES_DIR/bin/pomodoro" ] && link_target "$DOTFILES_DIR/bin/pomodoro" "$HOME/.local/bin/pomodoro"

    setup_git_repo
    log_success "Dotfiles symlinked successfully."
}

show_help() {
    echo "Usage: ./install.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  all         Execute full setup (default when no argument given)"
    echo "  apt         Install APT packages and configure services"
    echo "  zsh         Install oh-my-zsh and zsh-autosuggestions"
    echo "  flatpaks    Configure Flathub and install Flatpak apps"
    echo "  cli         Install manual CLI tools (nvm, aws, gh, claude, opencode, agy, ollama, pipx)"
    echo "  apps        Install manual desktop apps (Chrome, LibreWolf, Calibre, Obsidian, etc.)"
    echo "  dotfiles    Symlink Sway, Waybar, Mako, Wofi, terminal configs, helper scripts, and wallpaper"
    echo "  help        Display this help message"
}

main() {
    check_user
    bootstrap_dotfiles
    case "${1:-all}" in
        all)
            install_apt
            install_zsh
            install_flatpaks
            install_cli_tools
            install_desktop_apps
            install_dotfiles
            log_success "All stages completed successfully!"
            ;;
        apt)
            install_apt
            ;;
        zsh)
            install_zsh
            ;;
        flatpaks)
            install_flatpaks
            ;;
        cli)
            install_cli_tools
            ;;
        apps)
            install_desktop_apps
            ;;
        dotfiles)
            install_dotfiles
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
