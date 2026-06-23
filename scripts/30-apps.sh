#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

configure_plexamp() {
  if command -v plexamp >/dev/null 2>&1; then
    log "configuring Plexamp Electron flags"
    install_template \
      "$ARCH_SETUP_ROOT/config/templates/plexamp/plexamp-flags.conf" \
      "$HOME/.config/plexamp-flags.conf"
    install_template \
      "$ARCH_SETUP_ROOT/config/templates/plexamp/plexamp-flags.conf" \
      "$HOME/.config/Plexamp/plexamp-flags.conf"
  else
    warn "plexamp command not found after package install"
  fi
}

fetch_rustmon_data() {
  if command -v rustmon >/dev/null 2>&1; then
    log "fetching Rustmon Pokemon JSON/colorscripts with truecolor enabled"
    env -u NO_COLOR TERM=xterm-256color COLORTERM=truecolor rustmon fetch
  else
    warn "rustmon command not found after package install"
  fi
}

configure_plexamp
fetch_rustmon_data

