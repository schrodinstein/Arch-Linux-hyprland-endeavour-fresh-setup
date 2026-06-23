#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

install_bash_override() {
  log "installing ML4W Bash autostart override"
  install_template \
    "$ARCH_SETUP_ROOT/config/templates/bashrc/30-autostart" \
    "$HOME/.config/bashrc/custom/30-autostart"
}

install_zsh_override() {
  log "installing ML4W Zsh autostart override"
  install_template \
    "$ARCH_SETUP_ROOT/config/templates/zshrc/30-autostart" \
    "$HOME/.config/zshrc/custom/30-autostart"
}

install_fish_override() {
  log "installing Fish autostart override"
  install_template \
    "$ARCH_SETUP_ROOT/config/templates/fish/conf.d/30-autostart.fish" \
    "$HOME/.config/fish/conf.d/30-autostart.fish"
}

install_bash_override
install_zsh_override
install_fish_override
