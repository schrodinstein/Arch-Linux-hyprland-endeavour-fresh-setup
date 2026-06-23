#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[arch-setup] %s\n' "$*"
}

die() {
  printf '[arch-setup] ERROR: %s\n' "$*" >&2
  exit 1
}

if [[ ${EUID} -eq 0 ]]; then
  die "run this as your normal user, not root"
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  die "/etc/os-release not found"
fi

case " ${ID:-} ${ID_LIKE:-} " in
  *" arch "*|*" endeavouros "*) ;;
  *) die "expected EndeavourOS/Arch-like system, got ID=${ID:-unknown} ID_LIKE=${ID_LIKE:-unknown}" ;;
esac

REPO_URL="${ARCH_SETUP_REPO_URL:-https://github.com/schrodinstein/Arch-Linux-hyprland-endeavour-fresh-setup.git}"
TARGET_DIR="${ARCH_SETUP_DIR:-$HOME/.local/src/arch-setup}"

log "requesting sudo once for bootstrap prerequisites"
sudo -v

if ! command -v git >/dev/null 2>&1; then
  log "installing git/base-devel so the setup repo can be cloned"
  sudo pacman -Sy --needed --noconfirm git base-devel
fi

mkdir -p "$(dirname "$TARGET_DIR")"

if [[ -d "$TARGET_DIR/.git" ]]; then
  log "updating $TARGET_DIR"
  git -C "$TARGET_DIR" pull --ff-only
else
  if [[ -e "$TARGET_DIR" ]]; then
    die "$TARGET_DIR exists but is not a git checkout"
  fi
  log "cloning $REPO_URL into $TARGET_DIR"
  git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
fi

exec "$TARGET_DIR/scripts/master.sh" "$@"
