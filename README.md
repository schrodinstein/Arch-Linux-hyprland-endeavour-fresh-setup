# Arch Linux Hyprland Endeavour Fresh Setup

Single-command bootstrap for a fresh EndeavourOS or Arch-like ML4W/Hyprland workstation.

Repository description:

```text
Opinionated EndeavourOS/ML4W Hyprland bootstrap with Kitty, Fastfetch/Rustmon, Plexamp, native OpenVPN/Tailscale, Syncthing, Zed/Codex, Wallhaven wallpaper rotation, Inperiod, and terminal toys.
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

- Installs base tooling, Hyprland/ML4W prerequisites, Kitty, tmux, Fastfetch, Zed, Codex, Rust, Node, NetworkManager OpenVPN support, Syncthing, Tailscale, desktop portals, audio pieces, and native WebKit desktop app dependencies.
- Installs AUR apps currently tracked here: `rustmon-git` and `plexamp-bin`.
- Enables `NetworkManager.service`, `tailscaled.service`, and the per-user Syncthing and Tailscale tray services when systemd is available.
- Configures Tailscale for native nftables routing and lets the desktop user manage it without sudo.
- Installs `vpn-unlimited-import-ovpn` for importing VPN Unlimited manual OpenVPN profiles into NetworkManager.
- Installs Cargo terminal toys: `cyber-rain`, `rxpipes`, and `tarts` (`tarts donut`).
- Installs `mhfan/inperiod` as a native standalone periodic table app.
- Installs Wallhaven downloader support and fetches a fresh picker-compatible wallpaper every 20 minutes from `~/wallhaven-search-terms`.
- Runs ML4W OS install if ML4W is not already present.
- Fetches Rustmon Pokemon JSON/colorscripts with truecolor enabled.
- Configures new Kitty Bash/Zsh/Fish sessions to use a normal-size random Rustmon Pokemon with `--shiny 0.2` as the Fastfetch logo.
- Configures Zed with the Codex ACP agent settings.
- Creates a minimal Codex config without copying auth/session state.
- Configures tmux with Kitty truecolor, Wayland clipboard integration, and live colors from the current ML4W wallpaper palette.

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
ARCH_SETUP_NETWORKMANAGER_SERVICE=0 # install NetworkManager/OpenVPN but do not enable NetworkManager.service
ARCH_SETUP_TAILSCALE_SERVICE=0   # install Tailscale but do not enable tailscaled.service
ARCH_SETUP_TAILSCALE_SYSTRAY=0   # do not install or enable the Tailscale tray
ARCH_SETUP_TAILSCALE_FIREWALL_MODE=auto # use auto or iptables instead of nftables
ARCH_SETUP_SYNCTHING_SERVICE=0   # install Syncthing but do not enable the user service
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

Tailscale needs account-specific login after install. Use **Sign in** from its Waybar tray icon, or run:

```bash
tailscale up
```

The daemon runs at boot even when no user is logged in. The local browser GUI is available at [http://100.100.100.100](http://100.100.100.100); the tray provides connection state, account switching, and exit-node selection.

Syncthing starts as a user service and serves its local web UI at:

```text
http://127.0.0.1:8384
```

## VPN Unlimited

Use VPN Unlimited through native OpenVPN/NetworkManager rather than the official Linux app.

1. Log in to the KeepSolid User Office.
2. Generate and download a manual OpenVPN `.ovpn` profile for the desired server.
3. Import it:

```bash
vpn-unlimited-import-ovpn ~/Downloads/server.ovpn "VPN Unlimited Server"
nmcli connection up "VPN Unlimited Server"
```

Imported profiles are visible in NetworkManager-compatible desktop network settings.

## Keybinds

```text
SUPER+SHIFT+P        Open Inperiod periodic table
SUPER+SHIFT+ENTER    Open or reattach the persistent tmux main workspace
SUPER+CTRL+SHIFT+W   Fetch a fresh Wallhaven wallpaper
```

## tmux

tmux keeps its standard `CTRL+B` prefix. Splits inherit the active pane's directory, mouse support is enabled, and copied text goes directly to the Wayland clipboard. The status line is regenerated from ML4W's current Material palette whenever the wallpaper colors change. Rustmon/Fastfetch appears once per tmux session instead of filling every new pane.

```text
CTRL+B |             Split right
CTRL+B -             Split down
CTRL+B h/j/k/l       Move between panes
CTRL+B H/J/K/L       Resize panes
CTRL+B [             Enter vi copy mode; v selects and y copies
CTRL+B P             Paste from the Wayland clipboard
CTRL+B T             Open a temporary shell popup
CTRL+B r             Reload the configuration
```

The configuration is self-contained under `~/.config/tmux`; it does not require TPM or third-party plugins.

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
