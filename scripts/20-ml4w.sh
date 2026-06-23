#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

ml4w_present() {
  [[ -d "$HOME/.config/ml4w" ]] || [[ -d "$HOME/.mydotfiles/com.ml4w.dotfiles.stable" ]]
}

if [[ "${ARCH_SETUP_SKIP_ML4W:-0}" == "1" ]]; then
  log "skipping ML4W install by request"
  exit 0
fi

if ml4w_present; then
  log "ML4W appears to be installed; skipping upstream installer"
  exit 0
fi

channel="${ARCH_SETUP_ML4W_CHANNEL:-stable}"
case "$channel" in
  stable|rolling) ;;
  *) die "ARCH_SETUP_ML4W_CHANNEL must be stable or rolling" ;;
esac

log "running ML4W OS upstream installer channel=$channel"
log "upstream installer may prompt for choices"
bash <(curl -fsSL "https://ml4w.com/os/$channel")

