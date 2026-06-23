#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

configure_zed() {
  log "installing Zed settings"
  if [[ -e "$HOME/.config/zed/settings.json" ]]; then
    backup_file "$HOME/.config/zed/settings.json"
  fi
  install_template "$ARCH_SETUP_ROOT/config/templates/zed/settings.json" "$HOME/.config/zed/settings.json"
}

configure_codex() {
  log "installing Codex config without auth/session state"
  mkdir -p "$HOME/.codex"
  if [[ -e "$HOME/.codex/config.toml" ]]; then
    backup_file "$HOME/.codex/config.toml"
  fi

  toml_string() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '"%s"' "$value"
  }

  {
    printf '[projects.%s]\n' "$(toml_string "$HOME")"
    printf 'trust_level = "trusted"\n\n'
    printf '[projects.%s]\n' "$(toml_string "$ARCH_SETUP_ROOT")"
    printf 'trust_level = "trusted"\n'
  } > "$HOME/.codex/config.toml"
  chmod 0600 "$HOME/.codex/config.toml"
}

configure_zed
configure_codex

warn "Codex auth is intentionally not copied. Run 'codex login' after bootstrap."
