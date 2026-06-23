#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

INPERIOD_REPO_URL="${ARCH_SETUP_INPERIOD_REPO_URL:-https://github.com/mhfan/inperiod.git}"
INPERIOD_REF="${ARCH_SETUP_INPERIOD_REF:-}"
INPERIOD_SRC_DIR="${ARCH_SETUP_INPERIOD_SRC_DIR:-$HOME/.local/src/inperiod}"
INPERIOD_INSTALL_DIR="${ARCH_SETUP_INPERIOD_INSTALL_DIR:-$HOME/.local/opt/inperiod}"
INPERIOD_BIN="$INPERIOD_SRC_DIR/target/release/inperiod"

ensure_source() {
  need_cmd git

  if [[ "${ARCH_SETUP_INPERIOD_SKIP_UPDATE:-0}" == 1 ]]; then
    [[ -d "$INPERIOD_SRC_DIR" ]] || die "Inperiod source directory not found: $INPERIOD_SRC_DIR"
    log "using existing Inperiod source at $INPERIOD_SRC_DIR"
    return 0
  fi

  mkdir -p "$(dirname "$INPERIOD_SRC_DIR")"
  if [[ -d "$INPERIOD_SRC_DIR/.git" ]]; then
    log "updating Inperiod source"
    if [[ -n "$INPERIOD_REF" ]]; then
      git -C "$INPERIOD_SRC_DIR" fetch --depth=1 origin "$INPERIOD_REF"
      git -C "$INPERIOD_SRC_DIR" checkout --detach FETCH_HEAD
    else
      git -C "$INPERIOD_SRC_DIR" pull --ff-only
    fi
  else
    backup_file "$INPERIOD_SRC_DIR"
    log "cloning Inperiod source"
    git clone --depth=1 "$INPERIOD_REPO_URL" "$INPERIOD_SRC_DIR"
    if [[ -n "$INPERIOD_REF" ]]; then
      git -C "$INPERIOD_SRC_DIR" fetch --depth=1 origin "$INPERIOD_REF"
      git -C "$INPERIOD_SRC_DIR" checkout --detach FETCH_HEAD
    fi
  fi
}

generate_tailwind_css() {
  if [[ "${ARCH_SETUP_INPERIOD_SKIP_CSS:-0}" == 1 ]]; then
    return 0
  fi

  need_cmd npm
  need_cmd npx

  log "generating Inperiod Tailwind CSS"
  (
    cd "$INPERIOD_SRC_DIR"
    npm install --no-save --no-audit --no-fund tailwindcss @tailwindcss/cli
    npx @tailwindcss/cli -i input.css -o assets/tailwind.css -m
  )
}

build_inperiod() {
  if [[ "${ARCH_SETUP_INPERIOD_SKIP_BUILD:-0}" == 1 ]]; then
    [[ -x "$INPERIOD_BIN" ]] || die "Inperiod binary not found: $INPERIOD_BIN"
    log "using existing Inperiod binary at $INPERIOD_BIN"
    return 0
  fi

  need_cmd cargo

  log "building Inperiod native desktop app"
  (
    cd "$INPERIOD_SRC_DIR"
    cargo build --release --no-default-features --features desktop
  )
}

install_launcher() {
  local launcher="$HOME/.local/bin/inperiod"
  local escaped_install_dir
  local tmp

  escaped_install_dir=$(printf '%q' "$INPERIOD_INSTALL_DIR")
  tmp=$(mktemp)
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -Eeuo pipefail\n'
    printf 'cd %s\n' "$escaped_install_dir"
    printf 'exec ./inperiod "$@"\n'
  } > "$tmp"
  install -Dm755 "$tmp" "$launcher"
  rm -f "$tmp"
}

install_desktop_entry() {
  local desktop_file="$HOME/.local/share/applications/inperiod.desktop"
  local icon_file="$HOME/.local/share/icons/hicolor/scalable/apps/inperiod.svg"
  local tmp

  install -Dm644 "$INPERIOD_SRC_DIR/assets/ptable.svg" "$icon_file"

  tmp=$(mktemp)
  cat > "$tmp" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Inperiod
GenericName=Periodic Table
Comment=Interactive periodic table of chemical elements
Exec=$HOME/.local/bin/inperiod
Icon=inperiod
Categories=Science;Chemistry;
Terminal=false
StartupNotify=true
DESKTOP
  install -Dm644 "$tmp" "$desktop_file"
  rm -f "$tmp"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
}

install_inperiod() {
  [[ -x "$INPERIOD_BIN" ]] || die "Inperiod binary not found: $INPERIOD_BIN"
  [[ -f "$INPERIOD_SRC_DIR/assets/tailwind.css" ]] || die "Inperiod Tailwind CSS was not generated"

  log "installing Inperiod to $INPERIOD_INSTALL_DIR"
  install -Dm755 "$INPERIOD_BIN" "$INPERIOD_INSTALL_DIR/inperiod"
  install -Dm644 "$INPERIOD_SRC_DIR/index.html" "$INPERIOD_INSTALL_DIR/index.html"
  rsync -a --delete "$INPERIOD_SRC_DIR/assets/" "$INPERIOD_INSTALL_DIR/assets/"

  install_launcher
  install_desktop_entry
}

ensure_source
generate_tailwind_css
build_inperiod
install_inperiod

log "Inperiod installed: $HOME/.local/bin/inperiod"
