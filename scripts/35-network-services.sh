#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

enable_system_service() {
  local service=$1
  local label=$2

  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found; skipping $label service"
    return 0
  fi

  if ! systemctl cat "$service" >/dev/null 2>&1; then
    warn "$label service not found: $service"
    return 0
  fi

  log "enabling $label service: $service"
  if ! sudo systemctl enable --now "$service"; then
    warn "could not enable $label service: $service"
  fi
}

enable_user_service() {
  local service=$1
  local label=$2

  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found; skipping $label user service"
    return 0
  fi

  if ! systemctl --user cat "$service" >/dev/null 2>&1; then
    warn "$label user service not found or user systemd is unavailable: $service"
    return 0
  fi

  log "enabling $label user service: $service"
  if ! systemctl --user enable --now "$service"; then
    warn "could not enable $label user service: $service"
  fi
}

if [[ "${ARCH_SETUP_TAILSCALE_SERVICE:-1}" == "1" ]]; then
  enable_system_service tailscaled.service Tailscale
else
  warn "Tailscale service enablement disabled"
fi

if [[ "${ARCH_SETUP_VPN_UNLIMITED_SERVICE:-1}" == "1" ]]; then
  enable_system_service vpn-unlimited-daemon.service "VPN Unlimited"
else
  warn "VPN Unlimited daemon enablement disabled"
fi

if [[ "${ARCH_SETUP_SYNCTHING_SERVICE:-1}" == "1" ]]; then
  enable_user_service syncthing.service Syncthing
else
  warn "Syncthing user service enablement disabled"
fi

warn "Tailscale auth is manual. Run 'sudo tailscale up' after bootstrap."
warn "VPN Unlimited account login is manual. Open the VPN Unlimited desktop app after bootstrap."
