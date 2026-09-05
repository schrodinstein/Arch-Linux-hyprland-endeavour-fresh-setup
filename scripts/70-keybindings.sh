#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

KEYBINDINGS_FILE="${ARCH_SETUP_HYPR_KEYBINDINGS:-$HOME/.config/hypr/conf/keybindings/default.lua}"
WALLPAPER_BIND='hl.bind(mainMod .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd("systemctl --user start ml4w-wallhaven-wallpaper.service"), { description = "Fetch a fresh random wallpaper" })'
INPERIOD_BIND='hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("~/.local/bin/inperiod"), { description = "Open Inperiod periodic table" })'
TMUX_BIND='hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty --class tmux-workspace --title tmux:main -e ~/.local/bin/tmux-workspace main"), { description = "Open persistent tmux workspace" })'

configure_wallpaper_keybind() {
  if [[ ! -f "$KEYBINDINGS_FILE" ]]; then
    warn "Hyprland keybinding file not found: $KEYBINDINGS_FILE"
    return 0
  fi

  if grep -Fq 'systemctl --user start ml4w-wallhaven-wallpaper.service' "$KEYBINDINGS_FILE"; then
    local description_tmp
    description_tmp=$(mktemp)
    sed 's/Fetch a fresh Wallhaven wallpaper/Fetch a fresh random wallpaper/' \
      "$KEYBINDINGS_FILE" > "$description_tmp"
    install -m 0644 "$description_tmp" "$KEYBINDINGS_FILE"
    rm -f "$description_tmp"
    log "SUPER+CTRL+SHIFT+W wallpaper refresh binding already present"
    return 0
  fi

  if grep -Eq 'CTRL \+ SHIFT \+ W|SHIFT \+ CTRL \+ W' "$KEYBINDINGS_FILE"; then
    log "SUPER+CTRL+SHIFT+W binding already present or unavailable"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  awk -v bind="$WALLPAPER_BIND" '
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
  log "added SUPER+CTRL+SHIFT+W wallpaper refresh binding"
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

configure_tmux_keybind() {
  if [[ ! -f "$KEYBINDINGS_FILE" ]]; then
    warn "Hyprland keybinding file not found: $KEYBINDINGS_FILE"
    return 0
  fi

  if grep -Eq 'mainMod \.\. " \+ SHIFT \+ RETURN"' "$KEYBINDINGS_FILE"; then
    log "SUPER+SHIFT+RETURN binding already present or unavailable"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  awk -v bind="$TMUX_BIND" '
    {
      print
      if (!inserted && $0 ~ /mainMod \.\. " \+ RETURN"/) {
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
  log "added SUPER+SHIFT+RETURN persistent tmux workspace binding"
}

configure_wallpaper_keybind
configure_inperiod_keybind
configure_tmux_keybind
