#!/usr/bin/env bash

set -Eeuo pipefail

if [[ -z "${ARCH_SETUP_ROOT:-}" ]]; then
  ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

log() {
  printf '[arch-setup] %s\n' "$*"
}

warn() {
  printf '[arch-setup] WARN: %s\n' "$*" >&2
}

die() {
  printf '[arch-setup] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

is_arch_like() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case " ${ID:-} ${ID_LIKE:-} " in
    *" arch "*|*" endeavouros "*) return 0 ;;
    *) return 1 ;;
  esac
}

strip_package_file() {
  local file=$1
  sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$file"
}

backup_file() {
  local path=$1
  if [[ -e "$path" || -L "$path" ]]; then
    local backup="${path}.bak.$(date +%Y%m%d%H%M%S)"
    log "backing up $path to $backup"
    mv "$path" "$backup"
  fi
}

install_template() {
  local src=$1
  local dest=$2
  install -Dm644 "$src" "$dest"
}

ensure_user() {
  if [[ ${EUID} -eq 0 ]]; then
    die "run as the target user, not root"
  fi
}

