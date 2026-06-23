# Arch Linux Hyprland Endeavour Fresh Setup

Single-command bootstrap for a fresh EndeavourOS or Arch-like ML4W/Hyprland workstation.

Repository description:

```text
Opinionated EndeavourOS/ML4W Hyprland bootstrap with Kitty, Fastfetch/Rustmon, Plexamp, Zed/Codex, Wallhaven wallpaper rotation, Inperiod, and terminal toys.
```

## Target System

- Fresh EndeavourOS or Arch-like install.
- Network is available.
- Run as the target desktop user, not root.
- ML4W may already be installed. If it is missing, the master script can run the upstream ML4W installer.

## One Command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/schrodinstein/Arch-Linux-hyprland-endeavour-fresh-setup/main/bootstrap.sh)
```

For a fork or private copy, override the clone URL:

```bash
ARCH_SETUP_REPO_URL=https://github.com/YOUR_USER/YOUR_REPO.git \
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/bootstrap.sh)
```

For an already cloned checkout:

```bash
./scripts/master.sh
```

## What It Does

- Installs base tooling, Hyprland/ML4W prerequisites, Kitty, Fastfetch, Zed, Codex, Rust, Node, desktop portals, audio pieces, and native WebKit desktop app dependencies.
- Installs AUR apps currently tracked here: `rustmon-git` and `plexamp-bin`.
- Installs Cargo terminal toys: `cyber-rain`, `rxpipes`, and `tarts` (`tarts donut`).
- Installs `mhfan/inperiod` as a native standalone periodic table app.
- Installs Wallhaven downloader support and fetches a fresh picker-compatible wallpaper every 20 minutes from `~/wallhaven-search-terms`.
- Runs ML4W OS install if ML4W is not already present.
- Fetches Rustmon Pokemon JSON/colorscripts with truecolor enabled.
- Configures new Kitty Bash/Zsh/Fish sessions to use a normal-size random Rustmon Pokemon with `--shiny 0.2` as the Fastfetch logo.
- Configures Zed with the Codex ACP agent settings.
- Creates a minimal Codex config without copying auth/session state.

## Temporary Sudo

By default the master script asks for sudo once, installs a temporary sudoers drop-in, and revokes it on exit:

```text
/etc/sudoers.d/90-arch-setup-temp
```

Disable that behavior with:

```bash
ARCH_SETUP_TEMP_SUDO=0 ./scripts/master.sh
```

Manual revocation:

```bash
sudo rm -f /etc/sudoers.d/90-arch-setup-temp
sudo -k
```

## Useful Overrides

```bash
ARCH_SETUP_ML4W_CHANNEL=stable   # stable or rolling
ARCH_SETUP_SKIP_ML4W=1           # skip ML4W upstream installer
ARCH_SETUP_TEMP_SUDO=0           # do not create temporary NOPASSWD sudo rule
ARCH_SETUP_WALLHAVEN_TIMER=0     # install Wallhaven support but do not enable the 20-minute user timer
ARCH_SETUP_INPERIOD_REF=v0.1.6   # optional git ref/tag/branch for mhfan/inperiod
ARCH_SETUP_DIR=$HOME/.local/src/arch-setup
```

## Auth Left Manual

The scripts install and configure Codex/Zed, but do not copy private auth files.
After bootstrap:

```bash
codex login
zeditor
```

## Keybinds

```text
SUPER+SHIFT+P        Open Inperiod periodic table
SUPER+CTRL+SHIFT+W   Fetch a fresh Wallhaven wallpaper
```

## Terminal Toys

```bash
cyber-rain --preset cyberpunk --fps 60
rxpipes
tarts donut
```

## Inperiod

```bash
inperiod
```

## Wallhaven

Search terms live in:

```bash
~/wallhaven-search-terms
```

The timer fetches one new picker-compatible wallpaper every 20 minutes and keeps the most recent 72 Wallhaven downloads beside the ML4W defaults.

```bash
systemctl --user list-timers ml4w-wallhaven-wallpaper.timer
systemctl --user start ml4w-wallhaven-wallpaper.service
systemctl --user disable --now ml4w-wallhaven-wallpaper.timer
```

## GOG Game Installers

Local GOG Linux `.sh` installers can be installed with a tracked per-user wrapper:

```bash
./scripts/gog-game.sh verify ~/Downloads/game_installer.sh
./scripts/gog-game.sh install ~/Downloads/game_installer.sh
./scripts/gog-game.sh list
./scripts/gog-game.sh uninstall game-slug
```

Defaults:

- Games install under `~/Games/GOG/<slug>`.
- Metadata is stored under `~/.local/state/gog-games/<slug>`.
- GOG/MojoSetup installers run with unattended flags by default.
- Uninstall uses the bundled GOG uninstaller and removes tracked desktop/menu files.
- Game saves and config outside the install directory are left alone.

Run installs from a real terminal; some MojoSetup installers need an attached TTY even in unattended mode.
Use `--interactive` if a specific installer needs MojoSetup's terminal UI.

## Validation

```bash
bash -n scripts/*.sh scripts/lib/*.sh
./scripts/90-verify.sh
```

## License

MIT. See [LICENSE](LICENSE).
