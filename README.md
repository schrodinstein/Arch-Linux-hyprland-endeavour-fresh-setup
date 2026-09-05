# Arch Linux Hyprland Endeavour Fresh Setup

Single-command bootstrap for a fresh EndeavourOS or Arch-like ML4W/Hyprland workstation.

Repository description:

```text
Opinionated EndeavourOS/ML4W Hyprland bootstrap with Kitty, Fastfetch/Rustmon, native networking, office/PDF tools, Zed/Codex, wallpaper rotation, and terminal utilities.
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
- Installs Okular, PDF Arranger, QPDF, and PDF4QT, with Okular configured as the default PDF viewer.
- Installs AUR apps currently tracked here: `rustmon-git`, `plexamp-bin`, `blend2d`, and the source-built `pdf4qt` package.
- Installs SoftMaker Office NX and MegaFont NOW per-user when their paid archives are present in `~/Downloads`.
- Enables `NetworkManager.service`, `tailscaled.service`, and the per-user Syncthing and Tailscale tray services when systemd is available.
- Configures Tailscale for native nftables routing and lets the desktop user manage it without sudo.
- Installs `vpn-unlimited-import-ovpn` for importing VPN Unlimited manual OpenVPN profiles into NetworkManager.
- Installs Cargo terminal toys: `cyber-rain`, `rxpipes`, and `tarts` (`tarts donut`).
- Installs `mhfan/inperiod` as a native standalone periodic table app.
- Fetches a validated landscape wallpaper every 20 minutes from Wallhaven, Wikimedia Commons, NASA, The Met, or the Art Institute of Chicago.
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
ARCH_SETUP_SOFTMAKER=0           # skip the optional local SoftMaker archive
ARCH_SETUP_SOFTMAKER_ARCHIVE=/path/to/softmaker-office-nx-amd64.tgz
ARCH_SETUP_MEGAFONT=0            # skip the optional local MegaFont archive
ARCH_SETUP_MEGAFONT_ARCHIVE=/path/to/megafontnow.zip
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

## Office and PDF

The native document stack is:

- **Okular** for fast everyday PDF viewing and annotations. It is the PDF default.
- **PDF4QT Editor** for content editing, redaction, signatures, comparison, and prepress tools.
- **PDF Arranger** for page-level merge, split, reorder, crop, and rotation work.
- **QPDF** for reliable command-line inspection, repair, transformation, and automation.
- **SoftMaker Office NX** for the closest native Microsoft Office format compatibility in this setup.

The SoftMaker and MegaFont downloads are proprietary, so they are not stored in this repository. Put archives named like these in `~/Downloads` before running the bootstrap:

```text
softmaker-office-nx-1502-amd64.tgz
megafontnow.zip
```

The bootstrap extracts SoftMaker into `~/.local/opt`, installs only TTF/OTF files from MegaFont NOW, and never executes the bundled Windows font manager. Product keys are intentionally neither accepted nor stored by the scripts; activate Office in its own interface on first launch.

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
SUPER+CTRL+SHIFT+W   Fetch a fresh random wallpaper
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

## Wallpaper Rotation

Wallhaven topics live in:

```bash
~/wallhaven-search-terms
```

The other providers use editable topic files under:

```bash
~/.config/ml4w/wallpaper-sources/
```

Persistent shuffle bags make selection fair: every topic is attempted once before that provider repeats a topic. The default ten-slot provider cycle contains five Wallhaven, two curated [Wikimedia Commons](https://commons.wikimedia.org/wiki/Commons:API), and one each from the [NASA Image Library](https://images.nasa.gov/docs/images.nasa.gov_api_docs.pdf), [The Met Open Access collection](https://metmuseum.github.io/), and the [Art Institute of Chicago public-domain collection](https://api.artic.edu/docs/). A failed provider falls back to another source instead of leaving the wallpaper unchanged.

Every download is converted to a picker-compatible landscape JPEG of at least 1600x900. Commons results must include license metadata, NASA records with an explicit copyright field are skipped, and both museum APIs are restricted to public-domain works. The newest 72 generated wallpapers are kept beside the untouched ML4W defaults; attribution, source, and license records live outside the picker at `~/.local/state/ml4w-wallpapers/provenance/`.

Override the weighted cycle with a comma-separated list, for example:

```bash
WALLPAPER_PROVIDER_POOL=wallhaven,wikimedia,nasa ml4w-wallhaven-wallpaper
```

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
./scripts/gog-game.sh install --addon-to base-game-slug ~/Downloads/dlc_installer.sh
./scripts/gog-game.sh configure game-slug --env SDL_VIDEODRIVER=x11
./scripts/gog-game.sh configure game-slug --gamescope 1920x1080 native
./scripts/gog-game.sh launch game-slug
./scripts/gog-game.sh list
./scripts/gog-game.sh uninstall game-slug
```

Defaults:

- Games install under `~/Games/GOG/<slug>`.
- Metadata is stored under `~/.local/state/gog-games/<slug>`.
- GOG/MojoSetup installers run with unattended flags by default.
- Uninstall uses the bundled GOG uninstaller and removes tracked desktop/menu files.
- DLC installers are linked to their tracked base game automatically when their dependency metadata is available.
- Add-on removal deletes files introduced by the DLC and restores backups of any files it overwrote.
- Known compatibility profiles are applied automatically for Depth of Extinction, Halcyon 6, and Exiled Kingdoms; use `install --no-compat-profile` to opt out.
- Per-game launch environment overrides are stored outside vendor files and can be removed with `configure --reset`.
- Gamescope profiles can fit a legacy game's fixed resolution inside an explicit output size or the active output's `native` resolution.
- Installing DLC refreshes an existing managed launcher if the vendor installer overwrites it.
- Configured desktop entries are backed up, redirected through the managed launcher, and restored on reset.
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
