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

if [[ -f "$HOME/.local/share/rustmon/pokemon.json" ]]; then
  log "ok: Rustmon pokemon.json present"
else
  warn "missing Rustmon pokemon.json"
fi

log "verification complete"
