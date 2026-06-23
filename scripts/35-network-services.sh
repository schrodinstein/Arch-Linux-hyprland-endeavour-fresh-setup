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

install_vpn_unlimited_import_helper() {
  local helper="$HOME/.local/bin/vpn-unlimited-import-ovpn"
  local tmp

  tmp=$(mktemp)
  cat > "$tmp" <<'HELPER'
#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: vpn-unlimited-import-ovpn FILE.ovpn [connection-name]

Imports a VPN Unlimited manual OpenVPN profile into NetworkManager.

Example:
  vpn-unlimited-import-ovpn ~/Downloads/vpn-unlimited-us.ovpn "VPN Unlimited US"
  nmcli connection up "VPN Unlimited US"
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

ovpn_file=${1:-}
[[ -n "$ovpn_file" ]] || { usage >&2; exit 2; }
[[ -f "$ovpn_file" ]] || { printf 'missing .ovpn file: %s\n' "$ovpn_file" >&2; exit 1; }

command -v nmcli >/dev/null 2>&1 || { printf 'missing required command: nmcli\n' >&2; exit 1; }

base_name=$(basename "$ovpn_file")
connection_name=${2:-"VPN Unlimited ${base_name%.ovpn}"}

import_output=$(nmcli connection import type openvpn file "$ovpn_file")
printf '%s\n' "$import_output"

imported_name=$(sed -n "s/^Connection '\\(.*\\)' (.* successfully added\\.$/\\1/p" <<< "$import_output")
if [[ -n "$imported_name" && "$imported_name" != "$connection_name" ]]; then
  nmcli connection modify "$imported_name" connection.id "$connection_name"
  imported_name=$connection_name
fi

if [[ -n "$imported_name" ]]; then
  nmcli connection modify "$imported_name" connection.autoconnect no
  printf 'Imported: %s\n' "$imported_name"
  printf 'Connect with: nmcli connection up %q\n' "$imported_name"
else
  printf 'Import finished. Check the connection name with: nmcli connection show\n'
fi
HELPER

  install -Dm755 "$tmp" "$helper"
  rm -f "$tmp"
}

install_vpn_unlimited_import_helper

if [[ "${ARCH_SETUP_NETWORKMANAGER_SERVICE:-1}" == "1" ]]; then
  enable_system_service NetworkManager.service NetworkManager
else
  warn "NetworkManager service enablement disabled"
fi

if [[ "${ARCH_SETUP_TAILSCALE_SERVICE:-1}" == "1" ]]; then
  enable_system_service tailscaled.service Tailscale
else
  warn "Tailscale service enablement disabled"
fi

if [[ "${ARCH_SETUP_SYNCTHING_SERVICE:-1}" == "1" ]]; then
  enable_user_service syncthing.service Syncthing
else
  warn "Syncthing user service enablement disabled"
fi

warn "Tailscale auth is manual. Run 'sudo tailscale up' after bootstrap."
warn "VPN Unlimited uses native OpenVPN. Generate a manual .ovpn profile, then run 'vpn-unlimited-import-ovpn FILE.ovpn'."
