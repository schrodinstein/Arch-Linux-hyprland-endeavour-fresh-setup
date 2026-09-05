#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

ensure_user
need_cmd tmux

log "installing tmux configuration and ML4W theme integration"
install_template \
  "$ARCH_SETUP_ROOT/config/templates/tmux/tmux.conf" \
  "$HOME/.config/tmux/tmux.conf"
install -Dm755 \
  "$ARCH_SETUP_ROOT/config/templates/bin/tmux-ml4w-theme" \
  "$HOME/.local/bin/tmux-ml4w-theme"
install -Dm755 \
  "$ARCH_SETUP_ROOT/config/templates/bin/tmux-workspace" \
  "$HOME/.local/bin/tmux-workspace"
install_template \
  "$ARCH_SETUP_ROOT/config/templates/systemd/user/tmux-ml4w-theme.service" \
  "$HOME/.config/systemd/user/tmux-ml4w-theme.service"
install_template \
  "$ARCH_SETUP_ROOT/config/templates/systemd/user/tmux-ml4w-theme.path" \
  "$HOME/.config/systemd/user/tmux-ml4w-theme.path"

"$HOME/.local/bin/tmux-ml4w-theme" --apply

if tmux list-sessions >/dev/null 2>&1; then
  log "reloading the active tmux server"
  tmux source-file "$HOME/.config/tmux/tmux.conf"
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user daemon-reload && systemctl --user enable --now tmux-ml4w-theme.path; then
    log "enabled automatic tmux recoloring from ML4W wallpaper palettes"
  else
    warn "could not enable the tmux ML4W palette watcher"
  fi
else
  warn "systemctl not found; tmux colors will refresh when tmux starts or reloads"
fi

if [[ -e "$HOME/.tmux.conf" ]]; then
  warn "$HOME/.tmux.conf also exists and may override the managed XDG configuration"
fi
