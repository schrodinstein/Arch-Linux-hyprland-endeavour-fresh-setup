#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

INPERIOD_REPO_URL="${ARCH_SETUP_INPERIOD_REPO_URL:-https://github.com/mhfan/inperiod.git}"
INPERIOD_REF="${ARCH_SETUP_INPERIOD_REF:-}"
INPERIOD_SRC_DIR="${ARCH_SETUP_INPERIOD_SRC_DIR:-$HOME/.local/src/inperiod}"
INPERIOD_INSTALL_DIR="${ARCH_SETUP_INPERIOD_INSTALL_DIR:-$HOME/.local/opt/inperiod}"
INPERIOD_BUILD_APP_DIR="${ARCH_SETUP_INPERIOD_BUILD_APP_DIR:-$INPERIOD_SRC_DIR/target/dx/inperiod/release/linux/app}"
INPERIOD_BIN="${ARCH_SETUP_INPERIOD_BIN:-$INPERIOD_BUILD_APP_DIR/inperiod}"
DIOXUS_CLI_VERSION="${ARCH_SETUP_DIOXUS_CLI_VERSION:-0.7.9}"

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

patch_inperiod_source() {
  local main_rs="$INPERIOD_SRC_DIR/src/main.rs"
  if grep -q 'asset!("assets/crystal-s")' "$main_rs"; then
    log "patching Inperiod crystal asset directory reference"
    sed -i 's#let assets_crystal = format!("{}", asset!("assets/crystal-s"));#let assets_crystal = "/assets/crystal-s".to_string();#' "$main_rs"
  fi
}

prepare_inperiod_bundle_inputs() {
  # Upstream Dioxus.toml references public/* even though the repository does
  # not currently ship that directory.
  mkdir -p "$INPERIOD_SRC_DIR/public"
}

build_inperiod() {
  if [[ "${ARCH_SETUP_INPERIOD_SKIP_BUILD:-0}" == 1 ]]; then
    [[ -x "$INPERIOD_BIN" ]] || die "Inperiod binary not found: $INPERIOD_BIN"
    log "using existing Inperiod binary at $INPERIOD_BIN"
    return 0
  fi

  need_cmd cargo
  ensure_dioxus_cli
  ensure_rust_objcopy

  log "building Inperiod native desktop app with Dioxus asset bundling"
  (
    cd "$INPERIOD_SRC_DIR"
    dx build --platform desktop --release
  )
}

ensure_dioxus_cli() {
  local current=""
  if command -v dx >/dev/null 2>&1; then
    current=$(dx --version 2>/dev/null || true)
    if grep -q "$DIOXUS_CLI_VERSION" <<< "$current"; then
      return 0
    fi
    warn "found Dioxus CLI '$current', expected $DIOXUS_CLI_VERSION"
  fi

  log "installing Dioxus CLI $DIOXUS_CLI_VERSION for Inperiod asset bundling"
  cargo install dioxus-cli --version "$DIOXUS_CLI_VERSION" --locked --force
}

ensure_rust_objcopy() {
  local host rust_objcopy

  host=$(rustc -vV | awk '/^host:/ { print $2 }')
  rust_objcopy="$(rustc --print sysroot)/lib/rustlib/$host/bin/rust-objcopy"

  if [[ -x "$rust_objcopy" ]]; then
    return 0
  fi

  die "Dioxus needs $rust_objcopy. Install the Arch llvm package, then rerun this script."
}

install_launcher() {
  local launcher="$HOME/.local/bin/inperiod"
  local tmp

  tmp=$(mktemp)
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -Eeuo pipefail\n'
    printf 'exec %q "$@"\n' "$INPERIOD_INSTALL_DIR/inperiod"
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
  [[ -d "$INPERIOD_BUILD_APP_DIR" ]] || die "Inperiod Dioxus bundle not found: $INPERIOD_BUILD_APP_DIR"

  log "installing Inperiod to $INPERIOD_INSTALL_DIR"
  mkdir -p "$INPERIOD_INSTALL_DIR"
  rsync -a --delete "$INPERIOD_BUILD_APP_DIR/" "$INPERIOD_INSTALL_DIR/"
  rsync -a "$INPERIOD_SRC_DIR/assets/crystal-s/" "$INPERIOD_INSTALL_DIR/assets/crystal-s/"

  install_launcher
  install_desktop_entry
}

ensure_source
generate_tailwind_css
patch_inperiod_source
prepare_inperiod_bundle_inputs
build_inperiod
install_inperiod

log "Inperiod installed: $HOME/.local/bin/inperiod"
