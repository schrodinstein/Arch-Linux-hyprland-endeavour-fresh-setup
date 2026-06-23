#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
GOG_GAMES_DIR="${GOG_GAMES_DIR:-$HOME/Games/GOG}"
GOG_STATE_DIR="${GOG_STATE_DIR:-$XDG_STATE_HOME/gog-games}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/gog-game.sh verify INSTALLER.sh
  scripts/gog-game.sh install [options] INSTALLER.sh
  scripts/gog-game.sh list
  scripts/gog-game.sh uninstall [options] SLUG

Install options:
  --slug SLUG          Override detected game slug.
  --name NAME          Override detected display name.
  --dest DIR           Override install destination.
  --interactive        Use MojoSetup's terminal UI instead of unattended flags.
  --dry-run            Show what would happen without installing.
  --force              Allow installing into an existing directory/state slot.

Uninstall options:
  --yes                Do not prompt before uninstalling.
  --force              Remove tracked files even if the bundled uninstaller is missing or fails.
  --keep-install-dir   Run shortcut/state cleanup but leave the install directory alone.

Environment:
  GOG_GAMES_DIR        Default install root. Current: ~/Games/GOG
  GOG_STATE_DIR        Metadata root. Current: ~/.local/state/gog-games
  MOJOSETUP_UI         UI for interactive mode. Default: ncurses

Notes:
  Installs are per-user. Saves/config under game-specific XDG paths are not removed.
USAGE
}

shell_quote() {
  printf '%q' "$1"
}

manifest_path() {
  local slug=$1
  printf '%s/%s/manifest.env\n' "$GOG_STATE_DIR" "$slug"
}

state_dir_for_slug() {
  local slug=$1
  printf '%s/%s\n' "$GOG_STATE_DIR" "$slug"
}

clean_display_name() {
  local name=$1
  name="${name% (GOG.com)}"
  name="${name% (GOG)}"
  printf '%s\n' "$name"
}

slugify() {
  local value=$1
  value=$(clean_display_name "$value")
  printf '%s\n' "$value" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^[:alnum:]]\+/-/g' -e 's/^-//' -e 's/-$//'
}

detect_installer_label() {
  local installer=$1
  local label
  label=$(sed -n 's/^label="\([^"]*\)".*/\1/p' "$installer" | sed -n '1p')
  if [[ -n "$label" ]]; then
    clean_display_name "$label"
    return 0
  fi

  local base
  base=$(basename -- "$installer")
  base=${base%.sh}
  printf '%s\n' "$base"
}

is_gog_mojosetup_installer() {
  local installer=$1
  grep -aq 'mojosetup\|MojoSetup\|GOG.com installer' "$installer"
}

installer_sha256() {
  local installer=$1
  sha256sum "$installer" | awk '{print $1}'
}

default_install_dir() {
  local slug=$1
  printf '%s/%s\n' "$GOG_GAMES_DIR" "$slug"
}

snapshot_files() {
  local path
  for path in "$@"; do
    [[ -e "$path" ]] || continue
    find "$path" -xdev \( -type f -o -type l \) -print
  done | sort -u
}

write_manifest() {
  local slug=$1
  local name=$2
  local installer=$3
  local install_dir=$4
  local state_dir=$5
  local checksum=$6

  mkdir -p "$state_dir"
  {
    printf 'GOG_SLUG=%s\n' "$(shell_quote "$slug")"
    printf 'GOG_NAME=%s\n' "$(shell_quote "$name")"
    printf 'GOG_INSTALLER=%s\n' "$(shell_quote "$installer")"
    printf 'GOG_INSTALL_DIR=%s\n' "$(shell_quote "$install_dir")"
    printf 'GOG_INSTALLER_SHA256=%s\n' "$(shell_quote "$checksum")"
    printf 'GOG_INSTALLED_AT=%s\n' "$(shell_quote "$(date -Iseconds)")"
  } > "$state_dir/manifest.env"
}

load_manifest() {
  local slug=$1
  local manifest
  manifest=$(manifest_path "$slug")
  [[ -r "$manifest" ]] || die "no installed game metadata for slug: $slug"
  # shellcheck disable=SC1090
  . "$manifest"
}

verify_installer() {
  local installer=${1:-}
  [[ -n "$installer" ]] || die "missing installer path"
  [[ -f "$installer" ]] || die "installer not found: $installer"

  local name slug install_dir checksum
  name=$(detect_installer_label "$installer")
  slug=$(slugify "$name")
  install_dir=$(default_install_dir "$slug")
  checksum=$(installer_sha256 "$installer")

  if is_gog_mojosetup_installer "$installer"; then
    log "format: GOG/MojoSetup Makeself installer"
  else
    warn "format was not recognized as a GOG/MojoSetup installer"
  fi

  log "name: $name"
  log "slug: $slug"
  log "default install dir: $install_dir"
  log "sha256: $checksum"

  log "checking embedded archive integrity"
  sh "$installer" --check
}

run_installer() {
  local installer=$1
  local install_dir=$2
  local interactive=$3

  if [[ ! -t 0 || ! -t 1 ]]; then
    warn "MojoSetup may require a real terminal even with unattended flags"
  fi

  if [[ "$interactive" == "1" ]]; then
    MOJOSETUP_UI="${MOJOSETUP_UI:-ncurses}" \
      MOJOSETUP_NOTERMSPAWN=1 \
      sh "$installer" -- --destination "$install_dir"
  else
    MOJOSETUP_UI="${MOJOSETUP_UI:-ncurses}" \
      MOJOSETUP_NOTERMSPAWN=1 \
      sh "$installer" --noprogress -- \
        --i-agree-to-all-licenses \
        --noreadme \
        --nooptions \
        --destination "$install_dir"
  fi
}

install_game() {
  local installer=""
  local name=""
  local slug=""
  local install_dir=""
  local interactive=0
  local dry_run=0
  local force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slug)
        slug="${2:?missing slug}"
        shift 2
        ;;
      --name)
        name="${2:?missing name}"
        shift 2
        ;;
      --dest)
        install_dir="${2:?missing destination}"
        shift 2
        ;;
      --interactive)
        interactive=1
        shift
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      -*)
        die "unknown install option: $1"
        ;;
      *)
        [[ -z "$installer" ]] || die "unexpected extra argument: $1"
        installer=$1
        shift
        ;;
    esac
  done

  [[ -n "$installer" ]] || die "missing installer path"
  [[ -f "$installer" ]] || die "installer not found: $installer"
  installer="$(cd -- "$(dirname -- "$installer")" && pwd)/$(basename -- "$installer")"

  is_gog_mojosetup_installer "$installer" || die "not a recognized GOG/MojoSetup installer: $installer"

  if [[ -z "$name" ]]; then
    name=$(detect_installer_label "$installer")
  fi
  if [[ -z "$slug" ]]; then
    slug=$(slugify "$name")
  fi
  [[ -n "$slug" ]] || die "could not derive a usable slug"

  if [[ -z "$install_dir" ]]; then
    install_dir=$(default_install_dir "$slug")
  fi

  local state_dir checksum before after created
  state_dir=$(state_dir_for_slug "$slug")
  checksum=$(installer_sha256 "$installer")
  before="$state_dir/preinstall-files.txt"
  after="$state_dir/postinstall-files.txt"
  created="$state_dir/created-files.txt"

  log "name: $name"
  log "slug: $slug"
  log "installer: $installer"
  log "install dir: $install_dir"
  log "metadata dir: $state_dir"

  if [[ "$dry_run" == "1" ]]; then
    log "dry run only; no files will be installed"
    if [[ "$interactive" == "1" ]]; then
      log "installer mode: interactive ncurses"
    else
      log "installer mode: unattended MojoSetup flags"
    fi
    return 0
  fi

  ensure_user

  if [[ "$force" != "1" ]]; then
    [[ ! -e "$state_dir" ]] || die "metadata already exists for slug '$slug'; use --force to replace metadata"
    if [[ -d "$install_dir" ]]; then
      if find "$install_dir" -mindepth 1 -print -quit | grep -q .; then
        die "install directory is not empty: $install_dir"
      fi
    elif [[ -e "$install_dir" ]]; then
      die "install path exists and is not a directory: $install_dir"
    fi
  fi

  mkdir -p "$state_dir" "$(dirname -- "$install_dir")"

  cleanup_partial_metadata() {
    local status=$?
    if [[ "$status" != "0" && ! -f "$state_dir/manifest.env" ]]; then
      warn "removing incomplete metadata for failed install: $state_dir"
      rm -f -- "$before" "$after" "$created"
      rmdir -- "$state_dir" 2>/dev/null || true
    fi
    trap - RETURN
    return "$status"
  }
  trap cleanup_partial_metadata RETURN

  snapshot_files \
    "$install_dir" \
    "$XDG_DATA_HOME/applications" \
    "$XDG_DATA_HOME/icons" \
    "$HOME/Desktop" > "$before"

  log "running GOG installer"
  run_installer "$installer" "$install_dir" "$interactive"

  snapshot_files \
    "$install_dir" \
    "$XDG_DATA_HOME/applications" \
    "$XDG_DATA_HOME/icons" \
    "$HOME/Desktop" > "$after"
  comm -13 "$before" "$after" > "$created" || true

  write_manifest "$slug" "$name" "$installer" "$install_dir" "$state_dir" "$checksum"

  log "installed: $name"
  log "uninstall with: $ARCH_SETUP_ROOT/scripts/gog-game.sh uninstall $slug"
  trap - RETURN
}

list_games() {
  if [[ ! -d "$GOG_STATE_DIR" ]]; then
    log "no GOG games tracked yet"
    return 0
  fi

  local manifest found=0
  while IFS= read -r manifest; do
    # shellcheck disable=SC1090
    . "$manifest"
    printf '%-28s %s\n' "$GOG_SLUG" "$GOG_INSTALL_DIR"
    printf '  %s\n' "$GOG_NAME"
    found=1
  done < <(find "$GOG_STATE_DIR" -mindepth 2 -maxdepth 2 -name manifest.env -print | sort)

  if [[ "$found" == "0" ]]; then
    log "no GOG games tracked yet"
  fi
}

confirm_uninstall() {
  local slug=$1
  local yes=$2
  [[ "$yes" == "1" ]] && return 0
  [[ -t 0 ]] || die "refusing noninteractive uninstall without --yes"

  printf 'Uninstall %s from %s? [y/N] ' "$slug" "$GOG_INSTALL_DIR"
  local answer
  read -r answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) die "uninstall cancelled" ;;
  esac
}

find_uninstaller() {
  local install_dir=$1
  [[ -d "$install_dir" ]] || return 0
  find "$install_dir" -maxdepth 3 -type f \( -iname 'uninstall*.sh' -o -iname '*uninstall*' \) -print | sort | sed -n '1p'
}

remove_tracked_files() {
  local created_file=$1
  [[ -r "$created_file" ]] || return 0

  local path
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -e "$path" || -L "$path" ]] || continue

    case "$path" in
      "$GOG_INSTALL_DIR"/*)
        ;;
      "$XDG_DATA_HOME/applications"/*|"$XDG_DATA_HOME/icons"/*|"$HOME/Desktop"/*)
        log "removing tracked file: $path"
        rm -f -- "$path"
        ;;
      *)
        warn "leaving unrecognized tracked file outside install dir: $path"
        ;;
    esac
  done < "$created_file"
}

uninstall_game() {
  local slug=""
  local yes=0
  local force=0
  local keep_install_dir=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)
        yes=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      --keep-install-dir)
        keep_install_dir=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      -*)
        die "unknown uninstall option: $1"
        ;;
      *)
        [[ -z "$slug" ]] || die "unexpected extra argument: $1"
        slug=$1
        shift
        ;;
    esac
  done

  [[ -n "$slug" ]] || die "missing slug"
  load_manifest "$slug"
  confirm_uninstall "$slug" "$yes"

  local state_dir created_file uninstaller uninstall_failed=0
  state_dir=$(state_dir_for_slug "$slug")
  created_file="$state_dir/created-files.txt"

  if [[ "$keep_install_dir" != "1" ]]; then
    uninstaller=$(find_uninstaller "$GOG_INSTALL_DIR" || true)
    if [[ -n "$uninstaller" ]]; then
      log "running bundled uninstaller: $uninstaller"
      if ! MOJOSETUP_UI="${MOJOSETUP_UI:-ncurses}" MOJOSETUP_NOTERMSPAWN=1 sh "$uninstaller"; then
        uninstall_failed=1
        warn "bundled uninstaller failed"
      fi
    else
      uninstall_failed=1
      warn "no bundled uninstaller found under: $GOG_INSTALL_DIR"
    fi

    if [[ "$uninstall_failed" == "1" ]]; then
      [[ "$force" == "1" ]] || die "use --force to remove tracked files without a successful bundled uninstaller"
      log "force-removing install directory: $GOG_INSTALL_DIR"
      rm -rf -- "$GOG_INSTALL_DIR"
    fi
  fi

  remove_tracked_files "$created_file"
  rm -rf -- "$state_dir"
  log "uninstalled metadata for: $slug"
}

main() {
  local command=${1:-}
  case "$command" in
    verify)
      shift
      verify_installer "$@"
      ;;
    install)
      shift
      install_game "$@"
      ;;
    list)
      shift
      [[ $# -eq 0 ]] || die "list does not take arguments"
      list_games
      ;;
    uninstall)
      shift
      uninstall_game "$@"
      ;;
    --help|-h|"")
      usage
      ;;
    *)
      die "unknown command: $command"
      ;;
  esac
}

main "$@"
