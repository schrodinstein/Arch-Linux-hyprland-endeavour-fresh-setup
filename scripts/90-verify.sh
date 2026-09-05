#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

checks=(
  kitty
  fastfetch
  zeditor
  codex
  nmcli
  openvpn
  rustmon
  plexamp
  syncthing
  tailscale
  tmux
  tmux-ml4w-theme
  tmux-workspace
  vpn-unlimited-import-ovpn
  cyber-rain
  rxpipes
  tarts
  wallhaven-downloader
  ml4w-wallhaven-wallpaper
  inperiod
)

for cmd in "${checks[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    log "ok: $cmd -> $(command -v "$cmd")"
  else
    warn "missing: $cmd"
  fi
done

package_checks=(
  networkmanager-openvpn
)

for package in "${package_checks[@]}"; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    log "ok: package installed: $package"
  else
    warn "missing package: $package"
  fi
done

system_services=(
  NetworkManager.service
  tailscaled.service
)

for service in "${system_services[@]}"; do
  if systemctl is-active --quiet "$service"; then
    log "ok: system service active: $service"
  else
    warn "inactive system service: $service"
  fi
done

user_services=(
  syncthing.service
  tailscale-systray.service
)

for service in "${user_services[@]}"; do
  if systemctl --user is-active --quiet "$service"; then
    log "ok: user service active: $service"
  else
    warn "inactive user service: $service"
  fi
done

if systemctl --user is-active --quiet tmux-ml4w-theme.path; then
  log "ok: user path active: tmux-ml4w-theme.path"
else
  warn "inactive user path: tmux-ml4w-theme.path"
fi

if [[ -f "$HOME/.local/share/rustmon/pokemon.json" ]]; then
  log "ok: Rustmon pokemon.json present"
else
  warn "missing Rustmon pokemon.json"
fi

log "verification complete"
