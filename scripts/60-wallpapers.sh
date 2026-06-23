#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

WALLHAVEN_REPO="${ARCH_SETUP_WALLHAVEN_REPO:-https://github.com/macearl/Wallhaven-Downloader.git}"
WALLHAVEN_TMP="${ARCH_SETUP_WALLHAVEN_TMP:-${TMPDIR:-/tmp}/arch-setup-wallhaven-downloader}"
WALLPAPER_DIR="${ARCH_SETUP_WALLPAPER_DIR:-$HOME/.config/ml4w/wallpapers}"
TERMS_FILE="${ARCH_SETUP_WALLHAVEN_TERMS_FILE:-$HOME/wallhaven-search-terms}"
ENABLE_TIMER="${ARCH_SETUP_WALLHAVEN_TIMER:-1}"

clone_wallhaven_downloader() {
  need_cmd git

  if [[ "${ARCH_SETUP_WALLHAVEN_SKIP_CLONE:-0}" == "1" && -d "$WALLHAVEN_TMP" ]]; then
    log "using existing Wallhaven downloader checkout: $WALLHAVEN_TMP"
    return 0
  fi

  log "cloning Wallhaven downloader: $WALLHAVEN_REPO"
  rm -rf "$WALLHAVEN_TMP"
  git clone --depth 1 "$WALLHAVEN_REPO" "$WALLHAVEN_TMP"
}

install_wallhaven_downloader() {
  install -Dm755 "$WALLHAVEN_TMP/wallhaven.sh" "$HOME/.local/opt/wallhaven-downloader/wallhaven.sh"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$HOME/.local/opt/wallhaven-downloader/wallhaven.sh" "$HOME/.local/bin/wallhaven-downloader"
}

install_search_terms() {
  if [[ -f "$TERMS_FILE" ]]; then
    log "preserving existing Wallhaven search terms: $TERMS_FILE"
    return 0
  fi

  install_template \
    "$ARCH_SETUP_ROOT/config/templates/wallhaven/wallhaven-search-terms" \
    "$TERMS_FILE"
}

remove_dharmx_wallpapers() {
  mkdir -p "$WALLPAPER_DIR"

  log "removing dharmx wallpapers while keeping ML4W defaults"
  find "$WALLPAPER_DIR" -maxdepth 1 -type f -name 'dharmx-*' -delete
  rm -rf "$WALLPAPER_DIR/dharmx-walls"
  rm -f "$WALLPAPER_DIR/.arch-setup-dharmx-source"
}

configure_ml4w_wallpaper_settings() {
  local settings_dir="$HOME/.config/ml4w/settings"
  mkdir -p "$settings_dir"
  printf '%s\n' "$WALLPAPER_DIR" > "$settings_dir/wallpaper-folder"
  printf '1200\n' > "$settings_dir/wallpaper-automation"
}

install_wallhaven_timer() {
  install -Dm755 \
    "$ARCH_SETUP_ROOT/config/templates/bin/ml4w-wallhaven-wallpaper" \
    "$HOME/.local/bin/ml4w-wallhaven-wallpaper"

  install_template \
    "$ARCH_SETUP_ROOT/config/templates/systemd/user/ml4w-wallhaven-wallpaper.service" \
    "$HOME/.config/systemd/user/ml4w-wallhaven-wallpaper.service"
  install_template \
    "$ARCH_SETUP_ROOT/config/templates/systemd/user/ml4w-wallhaven-wallpaper.timer" \
    "$HOME/.config/systemd/user/ml4w-wallhaven-wallpaper.timer"

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now ml4w-random-wallpaper.timer >/dev/null 2>&1 || true
    rm -f \
      "$HOME/.config/systemd/user/ml4w-random-wallpaper.service" \
      "$HOME/.config/systemd/user/ml4w-random-wallpaper.timer"
  fi

  if [[ "$ENABLE_TIMER" == "1" ]] && command -v systemctl >/dev/null 2>&1; then
    log "enabling 20-minute Wallhaven wallpaper timer"
    if systemctl --user daemon-reload && systemctl --user enable --now ml4w-wallhaven-wallpaper.timer; then
      return 0
    fi
    warn "could not enable user timer automatically; timer files were installed"
  else
    warn "Wallhaven wallpaper timer installed but not enabled"
  fi
}

clone_wallhaven_downloader
install_wallhaven_downloader
install_search_terms
remove_dharmx_wallpapers
configure_ml4w_wallpaper_settings
install_wallhaven_timer
