#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/sudo.sh
. "$ARCH_SETUP_ROOT/scripts/lib/sudo.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/master.sh [options]

Options:
  --skip-ml4w        Do not run the upstream ML4W installer.
  --ml4w-channel C   ML4W channel: stable or rolling. Default: stable.
  --no-temp-sudo     Do not create a temporary NOPASSWD sudoers rule.
  --help             Show this help.

Environment:
  ARCH_SETUP_TEMP_SUDO=0
  ARCH_SETUP_SKIP_ML4W=1
  ARCH_SETUP_ML4W_CHANNEL=stable|rolling
  ARCH_SETUP_NETWORKMANAGER_SERVICE=0
  ARCH_SETUP_TAILSCALE_SERVICE=0
  ARCH_SETUP_SYNCTHING_SERVICE=0
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ml4w)
      export ARCH_SETUP_SKIP_ML4W=1
      shift
      ;;
    --ml4w-channel)
      export ARCH_SETUP_ML4W_CHANNEL="${2:?missing channel}"
      shift 2
      ;;
    --no-temp-sudo)
      export ARCH_SETUP_TEMP_SUDO=0
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

ensure_user

cleanup() {
  local status=$?
  revoke_temp_sudo
  exit "$status"
}
trap cleanup EXIT

install_temp_sudo

steps=(
  "00-preflight.sh"
  "10-packages.sh"
  "20-ml4w.sh"
  "30-apps.sh"
  "35-network-services.sh"
  "40-configure-shell.sh"
  "50-configure-codex-zed.sh"
  "60-wallpapers.sh"
  "65-inperiod.sh"
  "70-keybindings.sh"
  "90-verify.sh"
)

for step in "${steps[@]}"; do
  log "running $step"
  "$ARCH_SETUP_ROOT/scripts/$step"
done

log "bootstrap complete"
log "recommended next steps: reboot, log into Hyprland/ML4W, run 'codex login', then open Zed"
