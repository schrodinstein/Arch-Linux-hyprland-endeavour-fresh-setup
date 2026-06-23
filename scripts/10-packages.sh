#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

install_pacman_packages() {
  local file="$ARCH_SETUP_ROOT/config/packages/pacman.txt"
  mapfile -t packages < <(strip_package_file "$file")
  if (( ${#packages[@]} == 0 )); then
    warn "no pacman packages listed"
    return 0
  fi

  log "installing pacman packages"
  sudo pacman -Syu --needed --noconfirm "${packages[@]}"
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  log "installing yay from AUR"
  local build_dir
  build_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg -si --noconfirm)
  rm -rf "$build_dir"
}

install_aur_packages() {
  local file="$ARCH_SETUP_ROOT/config/packages/aur.txt"
  mapfile -t packages < <(strip_package_file "$file")
  if (( ${#packages[@]} == 0 )); then
    warn "no AUR packages listed"
    return 0
  fi

  ensure_yay
  log "installing AUR packages"
  yay -S --needed --noconfirm "${packages[@]}"
}

install_cargo_packages() {
  local file="$ARCH_SETUP_ROOT/config/packages/cargo.txt"
  [[ -f "$file" ]] || return 0

  need_cmd cargo

  local installed
  installed=$(cargo install --list 2>/dev/null || true)

  local crate version
  while read -r crate version; do
    [[ -n "${crate:-}" && -n "${version:-}" ]] || continue
    if grep -qE "^${crate//./\\.} v${version//./\\.}:" <<< "$installed"; then
      log "cargo crate already installed: $crate $version"
      continue
    fi

    log "installing cargo crate: $crate $version"
    cargo install --version "$version" "$crate"
  done < <(strip_package_file "$file")
}

install_pacman_packages
install_aur_packages
install_cargo_packages
