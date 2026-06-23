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
  rustmon
  plexamp
  syncthing
  tailscale
  cyber-rain
  rxpipes
  tarts
  wallhaven-downloader
  ml4w-wallhaven-wallpaper
  inperiod
)

if [[ "${ARCH_SETUP_SKIP_VPN_UNLIMITED:-0}" != "1" ]]; then
  checks+=(vpn-unlimited)
fi

for cmd in "${checks[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    log "ok: $cmd -> $(command -v "$cmd")"
  else
    warn "missing: $cmd"
  fi
done

if [[ -f "$HOME/.local/share/rustmon/pokemon.json" ]]; then
  log "ok: Rustmon pokemon.json present"
else
  warn "missing Rustmon pokemon.json"
fi

log "verification complete"
