# Debian 13 (Trixie) Sway Dotfiles & Post-Install Automation

Automated, reproducible, and minimal post-installation setup for **Debian 13 (Trixie)** using **Sway** as the primary Wayland desktop environment.

Everything is driven by human-readable plain-text manifests and a single modular script (`install.sh`).

---

## Quick Start on a Fresh Debian Install

Run directly with a single command via `curl` (no manual git installation or cloning required). Minimal Debian installs do not ship `curl`, so install it first — it is the one prerequisite the script cannot provide for itself:

```bash
sudo apt install curl
bash -c "$(curl -fsSL https://raw.githubusercontent.com/brianjag/dotfiles/main/install.sh)"
```

*The script automatically unpacks the repository into `~/dotfiles`, installs all APT packages, Flatpaks, and manual tools, symlinks your Sway desktop configurations and dotfiles, and configures Git tracking.*

---

### Running from an Existing Local Clone

If you already have the repository on your machine:

```bash
cd ~/dotfiles
./install.sh
```

---

## Modular Usage

You can run the full setup or execute specific stages on demand:

```bash
./install.sh [COMMAND]

Commands:
  all         Execute full setup (default when no argument given)
  apt         Install APT packages from 'packages' and enable services (mariadb, tlp)
  zsh         Install oh-my-zsh and zsh-autosuggestions
  flatpaks    Configure Flathub and install Flatpaks from 'flatpaks'
  cli         Install manual CLI tools (nvm + Node LTS, aws, gh, claude, opencode, agy, ollama, pipx)
  apps        Install manual desktop apps (Chrome, LibreWolf, Calibre, Obsidian, Beekeeper, etc.)
  dotfiles    Symlink Sway, Waybar, Mako, Wofi, terminal configs, helper scripts, and wallpaper
  help        Display help message
```

---

## Desktop Environment & Applications

* **Window Manager**: [Sway](https://swaywm.org/) (Wayland i3-compatible compositor)
* **Status Bar**: [Waybar](https://github.com/Alexays/Waybar) (with workspace scroll, weather, clock, audio, bluetooth, battery, tray)
* **Dock**: `nwg-dock` (GTK3 dock with pinned favorites and auto-hide; installed from the Debian sid build — not packaged in Trixie)
* **Application Launcher**: `wofi` (fuzzy search desktop applications)
* **Notifications**: `mako` (lightweight Wayland notification daemon)
* **Night Light**: `wlsunset` (gamma temperature transitions)
* **GTK Settings / Theming**: `nwg-look` (native Wayland GTK theming editor)
* **Wallpaper**: [Josh Nuttall](https://unsplash.com/photos/XVTWFHcNIko) on Unsplash, full resolution available there — the photo featured on The Minimalists' *[Valuable Things](https://www.theminimalists.com/valuable/)*. Tracked as `wallpaper.jpg` (1920x1280; Sway's `fill` crops it to the screen ratio)
* **Screenshots**: `grim` + `slurp` + `wl-clipboard`
* **File Managers**: `thunar` (GUI) and `lf` (terminal)
* **Terminals**: `alacritty`
* **Text Editor**: `l3afpad`
* **Calculator**: `mate-calc`
* **Image Viewer**: `imv`
* **PDF Viewer**: `mupdf`
* **Pomodoro**: Waybar module driven by `bin/pomodoro` (25 min work / 5 min break, click to start/pause, right-click to reset)
* **Flatpaks**: Insomnia, Spotify, Draw.io, CPU-X, KeePassXC, Audacity, MuseScore, Zeal, Ferdium, SweetHome3D, Pinta, GeoGebra.
* **Manual Desktop Apps**: JetBrains Toolbox AppImage, RustDesk, Google Chrome, LibreWolf, Calibre, Obsidian, Beekeeper Studio (`mariadb-server` via APT), Zoom, OnlyOffice, VS Code, Microsoft Edge, Dropbox.
* **CLI Runtimes & Tools**: `nvm` (+ Node LTS), AWS CLI v2, GitHub CLI (`gh`, also configures git credentials), Claude Code, OpenCode, Google Antigravity CLI (`agy`), Ollama, `yt-dlp` (via pipx), `buku` (via pipx), `beets` (via pipx), `tmux`, `pwgen`, `diceware`.

---

## Legacy Configs

`legacy/` holds old X11 window-manager configs (ratpoison, jwm, blackbox) kept
for reviving underpowered machines. Nothing there is installed or symlinked by
`install.sh`; see `legacy/README.md` for install lines and known breakage.

---

## Sway Keybindings Reference

Modifier key: **`Super`** (`Mod4`)

### Applications
| Shortcut | Action |
| :--- | :--- |
| `Super + Enter` | Open primary terminal (`alacritty`) |
| `Super + a` / `Super + d` | Open application launcher (`wofi`) |
| `Super + e` | Open file manager (`thunar`) |
| `Super + Shift + e` | Open text editor (`l3afpad`) |
| `Super + c` | Open calculator (`mate-calc`) |
| `Super + p` | Start / pause the Pomodoro timer |
| `Super + Escape` | Lock screen (`swaylock`) |
| `Print` | Drag-select screen region to clipboard |
| `Shift + Print` | Copy entire screen to clipboard |

### Window Management
| Shortcut | Action |
| :--- | :--- |
| `Super + Shift + q` | Close / kill focused window |
| `Super + h/j/k/l` | Focus left / down / up / right (Vim keys) |
| `Super + Shift + h/j/k/l` | Move focused window left / down / up / right |
| `Super + b` / `Super + v` | Split horizontally / vertically |
| `Super + s` / `Super + w` / `Super + t` | Stacking / Tabbed / Split layout |
| `Super + f` | Toggle fullscreen |
| `Super + Shift + Space` | Toggle floating mode |
| `Super + Shift + a` | Focus parent container |
| `Super + r` | Enter resize mode (`Escape` or `Enter` to exit) |

### Workspaces
| Shortcut | Action |
| :--- | :--- |
| `Super + 1..10` | Switch to workspace 1–10 |
| `Super + Shift + 1..10` | Move window to workspace 1–10 |
| `Super + Scroll Up/Down` | Cycle to previous / next workspace |
| `Scroll over Waybar` | Cycle to previous / next workspace |
| `Super + Tab` | Workspace overview overlay (`sov`) |
