#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

checks=(
  kitty
  fastfetch
  gamescope
  zeditor
  codex
  nmcli
  openvpn
  rustmon
  plexamp
  syncthing
  tailscale
  tmux
  okular
  pdfarranger
  qpdf
  Pdf4QtEditor
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
  blend2d
  networkmanager-openvpn
  pdf4qt
)

for package in "${package_checks[@]}"; do
  if pacman -Q "$package" >/dev/null 2>&1; then
    log "ok: package installed: $package"
  else
    warn "missing package: $package"
  fi
done

if [[ -e "$HOME/.local/opt/softmaker-office-nx/current" ]]; then
  for cmd in textmakernx planmakernx presentationsnx; do
    if command -v "$cmd" >/dev/null 2>&1; then
      log "ok: $cmd -> $(command -v "$cmd")"
    else
      warn "missing SoftMaker launcher: $cmd"
    fi
  done
else
  log "optional SoftMaker Office NX archive was not installed"
fi

if [[ -f "$HOME/.local/share/fonts/megafont-now-arch-setup/.source-sha256" ]]; then
  log "ok: MegaFont NOW user fonts installed"
else
  log "optional MegaFont NOW archive was not installed"
fi

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

wallpaper_term_files=(
  "$HOME/wallhaven-search-terms"
  "$HOME/.config/ml4w/wallpaper-sources/wikimedia-search-terms"
  "$HOME/.config/ml4w/wallpaper-sources/nasa-search-terms"
  "$HOME/.config/ml4w/wallpaper-sources/museum-search-terms"
)

for term_file in "${wallpaper_term_files[@]}"; do
  if [[ -s "$term_file" ]]; then
    log "ok: wallpaper search terms: $term_file"
  else
    warn "missing wallpaper search terms: $term_file"
  fi
done

log "verification complete"
