# Legacy X11 Configs (Revival Kit)

Old window-manager configs kept for the case of bringing up an underpowered
machine — an old laptop, a Raspberry Pi, anything that should not be running
Sway. Nothing here is installed or symlinked by `install.sh`; this directory is
inert unless you deliberately use it.

**Rules**

- Never symlink these into `~/.config`. They are X11-era configs for machines
  that will not have `~/.config/sway` at all.
- Do not add these programs to `packages` — that manifest targets Debian 13
  + Sway and should stay lean.
- Recover anything deleted from here with the usual:
  `git log --all --diff-filter=D --name-only`, then `git show <sha>:path`.

## Contents

| Config | Target path | Stack | Debian package |
| :--- | :--- | :--- | :--- |
| `x11/ratpoison/.ratpoisonrc` | `~/.ratpoisonrc` | X11 | `ratpoison` |
| `x11/jwm/.jwmrc` | `~/.jwmrc` | X11 | `jwm` |
| `x11/blackbox/.blackbox/menu` | `~/.blackbox/menu` | X11 | `blackbox` |
| `x11/mlterm/.mlterm` | `~/.mlterm` | X11 | `mlterm` |
| `x11/Xresources` | `~/.Xresources` | X11 | `rxvt-unicode` |

## Terminal (urxvt)

The URxvt theme lives here as `x11/Xresources`, and nothing on the Sway system
reads it — there is no `xrdb` call in `.sway/config`, so it is only loaded on a
revived box:

```
URxvt*background: black
URxvt*foreground: lightgray
URxvt*font: xft:monospace:size=12
URxvt*internalBorder: 8
```

On a revived box:

```bash
sudo apt install rxvt-unicode
ln -s ~/dotfiles/legacy/x11/Xresources ~/.Xresources
xrdb -merge ~/.Xresources   # must be re-run in every X session
```

For low-RAM machines, run the daemon and connect clients instead of one
process per terminal:

```bash
urxvtd -q -o -f     # start daemon
urxvtc              # clients
```

## ratpoison

Most personalized of the three, and the lightest option — the best fit for a
Pi or a 2000s laptop.

```bash
sudo apt install ratpoison xterm feh redshift x11-xkb-utils
ln -s ~/dotfiles/legacy/x11/ratpoison/.ratpoisonrc ~/
```

What it expects, and what will break:

- `escape Super_L` — Super is the ratpoison prefix key, not a WM modifier.
- Keyboard layout `latam,us,il` with `grp:alt_shift_toggle` (Argentina/Israel).
- `exec redshift` with no coordinates; `exec feh --bg-fill
  ~/Pictures/keepitsimplewhite1280x800.jpg`. That path does not exist, but the
  artwork is the *Keep It Simple* white wallpaper from The Minimalists:
  <https://www.theminimalists.com/wp-content/uploads/2010/12/keepitsimplewhite1280x800.jpg>
  Grab that 1280x800 file for a 1280x800 panel. It is **not** the repo's
  `../wallpaper.jpg`, which is Josh Nuttall's Unsplash photo — a different
  image entirely.
- Binds for `firefox`, `chromium`, `audacity`, `tuxguitar`, `gvim`,
  `xfce4-screenshooter`. Drop the ones you won't install; a dead bind fails
  silently.
- `exec xterm` on startup, so `xterm` (or your preferred `urxvt`) must exist.

No X session files were archived. Add `~/.xinitrc` with `exec ratpoison`, then
`startx`. No display manager needed.

## jwm

```bash
sudo apt install jwm feh slock firefox-esr xclock x11-xkb-utils
ln -s ~/dotfiles/legacy/x11/jwm/.jwmrc ~/
```

- `setxkbmap es` (Spanish layout) and `redshift -l -34.62:-58.41` (Paraná) are
  hard-coded at the top — adjust for the new location.
- Desktop background is `sh ~/.fehbg`, which only exists after running
  `feh --bg-fill <image>` once. Without it, desktops come up bare.
- Root menu is on right-click and uses `x-terminal-emulator`, `firefox-esr`,
  `slock`.
- Every icon path points at the **gnome icon theme**
  (`/usr/share/icons/gnome/...`), which is not installed by default anymore.
  Missing theme means a menu with no icons, not a failed start; install
  `gnome-icon-theme` if that matters.
- Tray at the bottom with pager, task list, clock (click clock → `xclock`).
- Has a `<Class>Pidgin</Class>` sticky rule left over from long ago; harmless.

## blackbox

No `.blackboxrc` was ever kept — blackbox ran on stock defaults, and it writes
`~/.blackboxrc` itself on first exit, so nothing is missing. Only the root menu
was customized:

```bash
sudo apt install blackbox urxvt-unicode remmina i3lock
mkdir -p ~/.blackbox
ln -s ~/dotfiles/legacy/x11/blackbox/.blackbox/menu ~/.blackbox/menu
```

One entry needs editing before use: `midori` is effectively gone from Debian.
`urxvt -ls` (login shell), `remmina`, and `i3lock` are all still packaged.

To capture settings again: start blackbox, change nothing, exit — a default
`~/.blackboxrc` appears, and it can be edited from there.

## mlterm

Kept for X11 revival only. mlterm had genuine bidi support, but it is
**X11-only** (so Sway would need XWayland) and was dropped from Trixie — last
packaged in bookworm, with sid still carrying 3.9.4. There is no native
Wayland replacement in this setup: RTL-capable alternatives pull in Qt/KDE,
and this desktop deliberately stays GTK-only, so RTL terminal support is
dropped.

On a revived X11 box:

```bash
sudo apt install mlterm
ln -s ~/dotfiles/legacy/x11/mlterm/.mlterm ~/.mlterm
```

The config carries the Catppuccin Mocha palette and 18px font, matching
alacritty. On bookworm this works natively; on Trixie you would need the sid
build (`mlterm 3.9.4-3`).
