#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

KEYBINDINGS_FILE="${ARCH_SETUP_HYPR_KEYBINDINGS:-$HOME/.config/hypr/conf/keybindings/default.lua}"
WALLHAVEN_BIND='hl.bind(mainMod .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd("systemctl --user start ml4w-wallhaven-wallpaper.service"), { description = "Fetch a fresh Wallhaven wallpaper" })'
INPERIOD_BIND='hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.local/bin/inperiod"), { description = "Open Inperiod periodic table" })'

configure_wallhaven_keybind() {
  if [[ ! -f "$KEYBINDINGS_FILE" ]]; then
    warn "Hyprland keybinding file not found: $KEYBINDINGS_FILE"
    return 0
  fi

  if grep -Eq 'CTRL \+ SHIFT \+ W|SHIFT \+ CTRL \+ W' "$KEYBINDINGS_FILE"; then
    log "SUPER+CTRL+SHIFT+W binding already present or unavailable"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  awk -v bind="$WALLHAVEN_BIND" '
    {
      print
      if (!inserted && $0 ~ /mainMod \.\. " \+ CTRL \+ W"/) {
        print bind
        inserted = 1
      }
    }
    END {
      if (!inserted) {
        print bind
      }
    }
  ' "$KEYBINDINGS_FILE" > "$tmp"

  install -m 0644 "$tmp" "$KEYBINDINGS_FILE"
  rm -f "$tmp"
  log "added SUPER+CTRL+SHIFT+W Wallhaven wallpaper refresh binding"
}

configure_inperiod_keybind() {
  if [[ ! -f "$KEYBINDINGS_FILE" ]]; then
    warn "Hyprland keybinding file not found: $KEYBINDINGS_FILE"
    return 0
  fi

  if grep -Eq 'mainMod \.\. " \+ SHIFT \+ P"' "$KEYBINDINGS_FILE"; then
    log "SUPER+SHIFT+P binding already present or unavailable"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  awk -v bind="$INPERIOD_BIND" '
    {
      print
      if (!inserted && $0 ~ /mainMod \.\. " \+ CTRL \+ P"/) {
        print bind
        inserted = 1
      }
    }
    END {
      if (!inserted) {
        print bind
      }
    }
  ' "$KEYBINDINGS_FILE" > "$tmp"

  install -m 0644 "$tmp" "$KEYBINDINGS_FILE"
  rm -f "$tmp"
  log "added SUPER+SHIFT+P Inperiod periodic table binding"
}

configure_wallhaven_keybind
configure_inperiod_keybind
