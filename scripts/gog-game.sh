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
  scripts/gog-game.sh configure [options] SLUG
  scripts/gog-game.sh launch SLUG [-- LAUNCHER_ARGS...]
  scripts/gog-game.sh list
  scripts/gog-game.sh uninstall [options] SLUG

Install options:
  --slug SLUG          Override detected game slug.
  --name NAME          Override detected display name.
  --dest DIR           Override install destination.
  --addon-to SLUG      Install DLC/add-on content into a tracked base game.
  --interactive        Use MojoSetup's terminal UI instead of unattended flags.
  --no-compat-profile  Do not apply a known per-game compatibility profile.
  --dry-run            Show what would happen without installing.
  --force              Allow installing into an existing directory/state slot.

Configure options:
  --env NAME=VALUE     Export an environment variable when launching; repeatable.
  --gamescope GAME_SIZE OUTPUT_SIZE
                       Fit GAME_SIZE inside a fullscreen OUTPUT_SIZE (for example,
                       1920x1080 native).
  --reset              Restore original desktop entries and remove launch overrides.

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
  Configure keeps compatibility settings outside vendor game files and updates launchers.
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

validate_slug() {
  local slug=$1
  [[ "$slug" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "invalid slug: $slug"
  [[ "$slug" != "." && "$slug" != ".." ]] || die "invalid slug: $slug"
}

validate_resolution() {
  local resolution=$1
  [[ "$resolution" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] \
    || die "invalid resolution (expected WIDTHxHEIGHT): $resolution"
}

validate_output_resolution() {
  local resolution=$1
  [[ "$resolution" == "native" ]] || validate_resolution "$resolution"
}

detect_native_output_resolution() {
  local resolution=""

  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] \
      && command -v hyprctl >/dev/null 2>&1 \
      && command -v jq >/dev/null 2>&1; then
    resolution=$(
      hyprctl monitors -j 2>/dev/null \
        | jq -er '([.[] | select(.focused == true)][0] // .[0]) | "\(.width)x\(.height)"' \
          2>/dev/null \
        || true
    )
  fi

  if [[ -z "$resolution" ]] && command -v xrandr >/dev/null 2>&1; then
    resolution=$(xrandr --current 2>/dev/null \
      | sed -n 's/.* current \([1-9][0-9]*\) x \([1-9][0-9]*\).*/\1x\2/p' \
      | sed -n '1p')
  fi

  [[ "$resolution" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] \
    || die "could not detect the active output resolution; configure an explicit WIDTHxHEIGHT"
  printf '%s\n' "$resolution"
}

normalize_install_dir() {
  local install_dir=$1
  [[ "$install_dir" == /* ]] || die "install destination must be an absolute path: $install_dir"

  install_dir=$(realpath -m -- "$install_dir")
  case "$install_dir" in
    /|"$HOME"|"$HOME/Games"|"$GOG_GAMES_DIR")
      die "refusing unsafe install destination: $install_dir"
      ;;
  esac
  printf '%s\n' "$install_dir"
}

manifest_field() {
  local slug=$1
  local field=$2
  local manifest
  manifest=$(manifest_path "$slug")
  [[ -r "$manifest" ]] || return 1

  (
    GOG_SLUG=""
    GOG_NAME=""
    GOG_INSTALL_DIR=""
    GOG_PARENT_SLUG=""
    GOG_DEPENDS=""
    GOG_UNINSTALLER=""
    # shellcheck disable=SC1090
    . "$manifest"
    case "$field" in
      GOG_SLUG) printf '%s\n' "$GOG_SLUG" ;;
      GOG_NAME) printf '%s\n' "$GOG_NAME" ;;
      GOG_INSTALL_DIR) printf '%s\n' "$GOG_INSTALL_DIR" ;;
      GOG_PARENT_SLUG) printf '%s\n' "$GOG_PARENT_SLUG" ;;
      GOG_DEPENDS) printf '%s\n' "$GOG_DEPENDS" ;;
      GOG_UNINSTALLER) printf '%s\n' "$GOG_UNINSTALLER" ;;
      *) return 1 ;;
    esac
  )
}

find_tracked_slug_by_name() {
  local expected_name=$1
  local manifest slug name
  [[ -d "$GOG_STATE_DIR" ]] || return 1

  while IFS= read -r manifest; do
    slug=$(basename -- "$(dirname -- "$manifest")")
    name=$(manifest_field "$slug" GOG_NAME || true)
    if [[ "$name" == "$expected_name" ]]; then
      printf '%s\n' "$slug"
      return 0
    fi
  done < <(find "$GOG_STATE_DIR" -mindepth 2 -maxdepth 2 -name manifest.env -print | sort)
  return 1
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
  label=$(head -n 80 -- "$installer" | sed -n 's/^label="\([^"]*\)".*/\1/p' | sed -n '1p')
  if [[ -n "$label" ]]; then
    clean_display_name "$label"
    return 0
  fi

  local base
  base=$(basename -- "$installer")
  base=${base%.sh}
  printf '%s\n' "$base"
}

detect_installer_dependency() {
  local installer=$1
  local config
  command -v unzip >/dev/null 2>&1 || return 0
  config=$(unzip -p "$installer" scripts/config.lua 2>/dev/null || true)
  sed -n 's/^[[:space:]]*local depends[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' <<< "$config" | sed -n '1p'
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

snapshot_dirs() {
  local path=$1
  [[ -d "$path" ]] || return 0
  find "$path" -xdev -type d -print | sort -u
}

snapshot_uninstallers() {
  local install_dir=$1
  [[ -d "$install_dir" ]] || return 0
  find "$install_dir" -maxdepth 3 -type f -iname 'uninstall*.sh' -print | sort -u
}

prepare_addon_backup() {
  local installer=$1
  local install_dir=$2
  local state_dir=$3
  local archive_files="$state_dir/archive-files.txt"
  local overwritten_files="$state_dir/overwritten-files.txt"
  local backup_dir="$state_dir/backup"
  local listing entry relative source backup

  need_cmd unzip
  listing=$(unzip -Z1 "$installer" 2>/dev/null || true)
  [[ -n "$listing" ]] || die "could not inspect add-on archive: $installer"
  : > "$archive_files"
  : > "$overwritten_files"

  while IFS= read -r entry; do
    [[ "$entry" == data/noarch/* ]] || continue
    relative=${entry#data/noarch/}
    [[ -n "$relative" && "$relative" != */ ]] || continue
    case "/$relative/" in
      */../*|*/./*) die "unsafe path in add-on archive: $relative" ;;
    esac

    printf '%s\n' "$relative" >> "$archive_files"
    source="$install_dir/$relative"
    if [[ -e "$source" || -L "$source" ]]; then
      [[ ! -d "$source" || -L "$source" ]] || die "add-on file would replace a directory: $source"
      backup="$backup_dir/$relative"
      mkdir -p -- "$(dirname -- "$backup")"
      cp -a -- "$source" "$backup"
      printf '%s\n' "$relative" >> "$overwritten_files"
    fi
  done <<< "$listing"
}

rollback_addon_files() {
  local install_dir=$1
  local state_dir=$2
  local created_file=$3
  local created_dirs_file=$4
  local overwritten_files="$state_dir/overwritten-files.txt"
  local backup_dir="$state_dir/backup"
  local path relative target backup

  if [[ -r "$created_file" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      case "$path" in
        "$install_dir"/*)
          if [[ -f "$path" || -L "$path" ]]; then
            log "removing add-on file: $path"
            rm -f -- "$path"
          fi
          ;;
      esac
    done < "$created_file"
  fi

  if [[ -r "$overwritten_files" ]]; then
    while IFS= read -r relative; do
      [[ -n "$relative" ]] || continue
      target="$install_dir/$relative"
      backup="$backup_dir/$relative"
      [[ -e "$backup" || -L "$backup" ]] || die "missing add-on backup: $backup"
      [[ ! -d "$target" || -L "$target" ]] || die "refusing to replace directory during add-on rollback: $target"
      mkdir -p -- "$(dirname -- "$target")"
      rm -f -- "$target"
      cp -a -- "$backup" "$target"
      log "restored pre-add-on file: $target"
    done < "$overwritten_files"
  fi

  if [[ -r "$created_dirs_file" ]]; then
    while IFS= read -r path; do
      case "$path" in
        "$install_dir"/*) rmdir -- "$path" 2>/dev/null || true ;;
      esac
    done < <(sort -r "$created_dirs_file")
  fi
}

find_child_addons() {
  local parent_slug=$1
  local manifest child_slug child_parent
  [[ -d "$GOG_STATE_DIR" ]] || return 0

  while IFS= read -r manifest; do
    child_slug=$(basename -- "$(dirname -- "$manifest")")
    child_parent=$(manifest_field "$child_slug" GOG_PARENT_SLUG || true)
    if [[ "$child_parent" == "$parent_slug" ]]; then
      printf '%s\n' "$child_slug"
    fi
  done < <(find "$GOG_STATE_DIR" -mindepth 2 -maxdepth 2 -name manifest.env -print | sort)
}

write_manifest() {
  local slug=$1
  local name=$2
  local installer=$3
  local install_dir=$4
  local state_dir=$5
  local checksum=$6
  local parent_slug=$7
  local dependency=$8
  local uninstaller=$9

  mkdir -p "$state_dir"
  {
    printf 'GOG_SLUG=%s\n' "$(shell_quote "$slug")"
    printf 'GOG_NAME=%s\n' "$(shell_quote "$name")"
    printf 'GOG_INSTALLER=%s\n' "$(shell_quote "$installer")"
    printf 'GOG_INSTALL_DIR=%s\n' "$(shell_quote "$install_dir")"
    printf 'GOG_INSTALLER_SHA256=%s\n' "$(shell_quote "$checksum")"
    printf 'GOG_INSTALLED_AT=%s\n' "$(shell_quote "$(date -Iseconds)")"
    printf 'GOG_PARENT_SLUG=%s\n' "$(shell_quote "$parent_slug")"
    printf 'GOG_DEPENDS=%s\n' "$(shell_quote "$dependency")"
    printf 'GOG_UNINSTALLER=%s\n' "$(shell_quote "$uninstaller")"
  } > "$state_dir/manifest.env"
}

load_manifest() {
  local slug=$1
  local manifest
  manifest=$(manifest_path "$slug")
  [[ -r "$manifest" ]] || die "no installed game metadata for slug: $slug"
  GOG_PARENT_SLUG=""
  GOG_DEPENDS=""
  GOG_UNINSTALLER=""
  # shellcheck disable=SC1090
  . "$manifest"
}

desktop_candidates() {
  local directory
  for directory in "$XDG_DATA_HOME/applications" "$HOME/Desktop"; do
    [[ -d "$directory" ]] || continue
    find "$directory" -mindepth 1 -maxdepth 1 -type f -name '*.desktop' -print
  done | sort -u
}

desktop_matches_game() {
  local desktop=$1
  local install_dir=$2
  grep -Fqx "Path=$install_dir" "$desktop" \
    || grep -Fq "\"$install_dir/start.sh\"" "$desktop"
}

rewrite_desktop_entry() {
  local desktop=$1
  local display_name=$2
  local launcher=$3
  local temporary
  temporary=$(mktemp "$(dirname -- "$desktop")/.gog-desktop.XXXXXX")

  awk -v display_name="$display_name" -v launcher="$launcher" '
    BEGIN { in_desktop_entry = 0 }
    /^\[Desktop Entry\]$/ { in_desktop_entry = 1; print; next }
    /^\[/ { in_desktop_entry = 0; print; next }
    in_desktop_entry && /^(Encoding|Value)=/ { next }
    in_desktop_entry && /^Name=/ { print "Name=" display_name; next }
    in_desktop_entry && /^GenericName=/ { print "GenericName=" display_name; next }
    in_desktop_entry && /^Comment=/ { print "Comment=Launch " display_name; next }
    in_desktop_entry && /^Exec=/ { print "Exec=" launcher; next }
    { print }
  ' "$desktop" > "$temporary"

  chmod --reference="$desktop" "$temporary"
  mv -f -- "$temporary" "$desktop"
}

configure_desktop_entries() {
  local install_dir=$1
  local state_dir=$2
  local display_name=$3
  local launcher=$4
  local backup_root="$state_dir/desktop-backups"
  local desktop backup configured=0

  while IFS= read -r desktop; do
    desktop_matches_game "$desktop" "$install_dir" || continue
    backup="$backup_root$desktop"
    if [[ ! -e "$backup" ]]; then
      mkdir -p -- "$(dirname -- "$backup")"
      cp -a -- "$desktop" "$backup"
    fi
    rewrite_desktop_entry "$desktop" "$display_name" "$launcher"
    log "configured desktop entry: $desktop"
    configured=1
  done < <(desktop_candidates)

  if [[ "$configured" == "0" ]]; then
    warn "no desktop entries referenced: $install_dir"
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$XDG_DATA_HOME/applications" >/dev/null 2>&1 || true
  fi
}

refresh_configured_desktop_entries() {
  local slug=$1
  local state_dir install_dir display_name launcher_command
  state_dir=$(state_dir_for_slug "$slug")
  [[ -r "$state_dir/launch.conf" ]] || return 0

  install_dir=$(manifest_field "$slug" GOG_INSTALL_DIR) \
    || die "configured game has no install destination: $slug"
  display_name=$(manifest_field "$slug" GOG_NAME) \
    || die "configured game has no display name: $slug"
  install_dir=$(normalize_install_dir "$install_dir")
  launcher_command="\"$ARCH_SETUP_ROOT/scripts/gog-game.sh\" launch $slug"
  configure_desktop_entries \
    "$install_dir" "$state_dir" "$display_name" "$launcher_command"
}

restore_desktop_entries() {
  local state_dir=$1
  local backup_root="$state_dir/desktop-backups"
  local backup target
  [[ -d "$backup_root" ]] || return 0

  while IFS= read -r backup; do
    target=${backup#"$backup_root"}
    [[ "$target" == /* ]] || die "invalid desktop backup path: $backup"
    mkdir -p -- "$(dirname -- "$target")"
    cp -a -- "$backup" "$target"
    log "restored desktop entry: $target"
  done < <(find "$backup_root" -type f -print | sort)

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$XDG_DATA_HOME/applications" >/dev/null 2>&1 || true
  fi
}

launch_game() {
  local slug=${1:-}
  [[ -n "$slug" ]] || die "missing slug"
  shift
  if [[ ${1:-} == "--" ]]; then
    shift
  fi

  validate_slug "$slug"
  load_manifest "$slug"
  [[ -z "$GOG_PARENT_SLUG" ]] || die "launch the base game instead: $GOG_PARENT_SLUG"
  GOG_INSTALL_DIR=$(normalize_install_dir "$GOG_INSTALL_DIR")
  ensure_user

  local state_dir launch_config launch_environment launch_target
  local assignment environment_name
  local gamescope_game_size=""
  local gamescope_output_size=""
  local -a game_environment=()
  state_dir=$(state_dir_for_slug "$slug")
  launch_config="$state_dir/launch.conf"
  launch_environment="$state_dir/launch.env"
  launch_target="$GOG_INSTALL_DIR/start.sh"

  if [[ -r "$launch_config" ]]; then
    GOG_LAUNCH_TARGET=""
    GOG_GAMESCOPE_GAME_SIZE=""
    GOG_GAMESCOPE_OUTPUT_SIZE=""
    # shellcheck disable=SC1090
    . "$launch_config"
    launch_target=${GOG_LAUNCH_TARGET:-$launch_target}
    gamescope_game_size=${GOG_GAMESCOPE_GAME_SIZE:-}
    gamescope_output_size=${GOG_GAMESCOPE_OUTPUT_SIZE:-}
  fi
  if [[ -r "$launch_environment" ]]; then
    mapfile -d '' -t game_environment < "$launch_environment"
    for assignment in "${game_environment[@]}"; do
      [[ "$assignment" == *=* ]] || die "invalid entry in launch environment"
      environment_name=${assignment%%=*}
      [[ "$environment_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
        || die "invalid variable in launch environment: $environment_name"
    done
  fi

  case "$launch_target" in
    "$GOG_INSTALL_DIR"/*) ;;
    *) die "configured launcher is outside the game directory: $launch_target" ;;
  esac
  [[ -x "$launch_target" ]] || die "game launcher is not executable: $launch_target"

  local -a launch_command=(env "${game_environment[@]}" "$launch_target" "$@")
  if [[ -n "$gamescope_game_size" || -n "$gamescope_output_size" ]]; then
    [[ -n "$gamescope_game_size" && -n "$gamescope_output_size" ]] \
      || die "both Gamescope resolutions must be configured"
    validate_resolution "$gamescope_game_size"
    validate_output_resolution "$gamescope_output_size"
    command -v gamescope >/dev/null 2>&1 || die "Gamescope is configured but not installed"

    if [[ "$gamescope_output_size" == "native" ]]; then
      gamescope_output_size=$(detect_native_output_resolution)
    fi

    local game_width=${gamescope_game_size%x*}
    local game_height=${gamescope_game_size#*x}
    local output_width=${gamescope_output_size%x*}
    local output_height=${gamescope_output_size#*x}
    local -a gamescope_command=(gamescope)
    if [[ ${XDG_SESSION_TYPE:-} == "wayland" ]]; then
      gamescope_command+=(--backend wayland)
    fi
    gamescope_command+=(
      -f
      -W "$output_width"
      -H "$output_height"
      -w "$game_width"
      -h "$game_height"
      -S fit
      --
    )
    launch_command=("${gamescope_command[@]}" "${launch_command[@]}")
  fi
  exec "${launch_command[@]}"
}

configure_game() {
  local slug=""
  local gamescope_game_size=""
  local gamescope_output_size=""
  local reset=0
  local assignment name value
  local -a launch_environment=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        assignment=${2:?missing NAME=VALUE}
        [[ "$assignment" == *=* ]] || die "environment override must be NAME=VALUE"
        name=${assignment%%=*}
        value=${assignment#*=}
        [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "invalid environment variable name: $name"
        [[ "$value" != *$'\n'* ]] || die "environment values cannot contain newlines"
        launch_environment+=("$assignment")
        shift 2
        ;;
      --gamescope)
        gamescope_game_size=${2:?missing game resolution}
        gamescope_output_size=${3:?missing output resolution}
        validate_resolution "$gamescope_game_size"
        validate_output_resolution "$gamescope_output_size"
        shift 3
        ;;
      --reset)
        reset=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      -*)
        die "unknown configure option: $1"
        ;;
      *)
        [[ -z "$slug" ]] || die "unexpected extra argument: $1"
        slug=$1
        shift
        ;;
    esac
  done

  [[ -n "$slug" ]] || die "missing slug"
  validate_slug "$slug"
  load_manifest "$slug"
  [[ -z "$GOG_PARENT_SLUG" ]] || die "configure the base game instead: $GOG_PARENT_SLUG"
  GOG_INSTALL_DIR=$(normalize_install_dir "$GOG_INSTALL_DIR")
  [[ -x "$GOG_INSTALL_DIR/start.sh" ]] || die "game launcher is missing: $GOG_INSTALL_DIR/start.sh"
  ensure_user

  local state_dir launch_config launch_environment_file temporary
  state_dir=$(state_dir_for_slug "$slug")
  launch_config="$state_dir/launch.conf"
  launch_environment_file="$state_dir/launch.env"

  if [[ "$reset" == "1" ]]; then
    [[ ${#launch_environment[@]} -eq 0 \
        && -z "$gamescope_game_size" \
        && -z "$gamescope_output_size" ]] \
      || die "--reset cannot be combined with launch overrides"
    restore_desktop_entries "$state_dir"
    rm -rf -- "$state_dir/desktop-backups"
    rm -f -- "$launch_config" "$launch_environment_file"
    log "removed launch overrides for: $slug"
    return 0
  fi

  temporary=$(mktemp "$state_dir/.launch.conf.XXXXXX")
  {
    printf 'GOG_LAUNCH_TARGET=%s\n' "$(shell_quote "$GOG_INSTALL_DIR/start.sh")"
    printf 'GOG_GAMESCOPE_GAME_SIZE=%s\n' "$(shell_quote "$gamescope_game_size")"
    printf 'GOG_GAMESCOPE_OUTPUT_SIZE=%s\n' "$(shell_quote "$gamescope_output_size")"
  } > "$temporary"
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$launch_config"

  temporary=$(mktemp "$state_dir/.launch.env.XXXXXX")
  : > "$temporary"
  for assignment in "${launch_environment[@]}"; do
    printf '%s\0' "$assignment" >> "$temporary"
  done
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$launch_environment_file"

  refresh_configured_desktop_entries "$slug"
  log "configured launch overrides for: $slug"
}

compatibility_profile_for_slug() {
  case "$1" in
    depth-of-extinction|halcyon-6-lightspeed-edition)
      printf '%s\n' "SDL X11 video backend"
      ;;
    exiled-kingdoms)
      printf '%s\n' "1920x1080 Gamescope fit on the active output"
      ;;
    *)
      return 1
      ;;
  esac
}

apply_known_compatibility_profile() {
  local slug=$1
  local profile
  profile=$(compatibility_profile_for_slug "$slug") || return 0
  log "applying compatibility profile: $profile"

  case "$slug" in
    depth-of-extinction|halcyon-6-lightspeed-edition)
      configure_game --env SDL_VIDEODRIVER=x11 "$slug"
      ;;
    exiled-kingdoms)
      configure_game --gamescope 1920x1080 native "$slug"
      ;;
  esac
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
  local parent_slug=""
  local dependency=""
  local destination_set=0
  local interactive=0
  local compat_profile=1
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
        destination_set=1
        shift 2
        ;;
      --addon-to)
        parent_slug="${2:?missing parent slug}"
        shift 2
        ;;
      --interactive)
        interactive=1
        shift
        ;;
      --no-compat-profile)
        compat_profile=0
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
  validate_slug "$slug"

  dependency=$(detect_installer_dependency "$installer")
  if [[ -z "$parent_slug" && -n "$dependency" ]]; then
    if ! parent_slug=$(find_tracked_slug_by_name "$dependency"); then
      die "add-on requires tracked base game '$dependency'; install it first or use --addon-to SLUG"
    fi
  fi

  local parent_name="" parent_install_dir=""
  if [[ -n "$parent_slug" ]]; then
    validate_slug "$parent_slug"
    parent_name=$(manifest_field "$parent_slug" GOG_NAME) || die "base game is not tracked: $parent_slug"
    parent_install_dir=$(manifest_field "$parent_slug" GOG_INSTALL_DIR) || die "base game has no install destination: $parent_slug"
    parent_install_dir=$(normalize_install_dir "$parent_install_dir")
    [[ -d "$parent_install_dir" ]] || die "base game install directory is missing: $parent_install_dir"

    if [[ -n "$dependency" && "$parent_name" != "$dependency" ]]; then
      die "add-on requires '$dependency', but '$parent_slug' tracks '$parent_name'"
    fi
    if [[ "$destination_set" == "1" ]]; then
      install_dir=$(normalize_install_dir "$install_dir")
      [[ "$install_dir" == "$parent_install_dir" ]] || die "add-on destination must match its base game: $parent_install_dir"
    fi
    install_dir=$parent_install_dir
  elif [[ -z "$install_dir" ]]; then
    install_dir=$(default_install_dir "$slug")
  fi
  install_dir=$(normalize_install_dir "$install_dir")

  local state_dir checksum before after created
  local before_dirs after_dirs created_dirs
  local before_uninstallers after_uninstallers created_uninstallers uninstaller=""
  state_dir=$(state_dir_for_slug "$slug")
  before="$state_dir/preinstall-files.txt"
  after="$state_dir/postinstall-files.txt"
  created="$state_dir/created-files.txt"
  before_dirs="$state_dir/preinstall-dirs.txt"
  after_dirs="$state_dir/postinstall-dirs.txt"
  created_dirs="$state_dir/created-dirs.txt"
  before_uninstallers="$state_dir/preinstall-uninstallers.txt"
  after_uninstallers="$state_dir/postinstall-uninstallers.txt"
  created_uninstallers="$state_dir/created-uninstallers.txt"

  log "name: $name"
  log "slug: $slug"
  if [[ -n "$parent_slug" ]]; then
    log "add-on for: $parent_name ($parent_slug)"
  fi
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
    if [[ -z "$parent_slug" && "$compat_profile" == "1" ]]; then
      local profile
      profile=$(compatibility_profile_for_slug "$slug" || true)
      [[ -z "$profile" ]] || log "compatibility profile: $profile"
    fi
    return 0
  fi

  ensure_user
  checksum=$(installer_sha256 "$installer")

  if [[ "$force" != "1" ]]; then
    [[ ! -e "$state_dir" ]] || die "metadata already exists for slug '$slug'; use --force to replace metadata"
    if [[ -z "$parent_slug" && -d "$install_dir" ]]; then
      if find "$install_dir" -mindepth 1 -print -quit | grep -q .; then
        die "install directory is not empty: $install_dir"
      fi
    elif [[ -z "$parent_slug" && -e "$install_dir" && ! -d "$install_dir" ]]; then
      die "install path exists and is not a directory: $install_dir"
    fi
  fi

  mkdir -p "$state_dir" "$(dirname -- "$install_dir")"

  if [[ -n "$parent_slug" ]]; then
    prepare_addon_backup "$installer" "$install_dir" "$state_dir"
  fi

  cleanup_partial_metadata() {
    local status=$?
    trap - RETURN
    if [[ "$status" != "0" && ! -f "$state_dir/manifest.env" ]]; then
      if [[ -n "$parent_slug" ]]; then
        warn "add-on install failed; attempting to restore the base game"
        snapshot_files \
          "$install_dir" \
          "$XDG_DATA_HOME/applications" \
          "$XDG_DATA_HOME/icons" \
          "$HOME/Desktop" > "$after" || true
        comm -13 "$before" "$after" > "$created" || true
        snapshot_dirs "$install_dir" > "$after_dirs" || true
        comm -13 "$before_dirs" "$after_dirs" > "$created_dirs" || true
        if rollback_addon_files "$install_dir" "$state_dir" "$created" "$created_dirs"; then
          rm -rf -- "$state_dir"
        else
          warn "automatic rollback was incomplete; recovery data remains in: $state_dir"
        fi
      else
        warn "removing incomplete metadata for failed install: $state_dir"
        rm -f -- "$before" "$after" "$created" "$before_dirs" "$after_dirs" "$created_dirs"
        rmdir -- "$state_dir" 2>/dev/null || true
      fi
    fi
    return "$status"
  }
  trap cleanup_partial_metadata RETURN

  snapshot_files \
    "$install_dir" \
    "$XDG_DATA_HOME/applications" \
    "$XDG_DATA_HOME/icons" \
    "$HOME/Desktop" > "$before"
  snapshot_dirs "$install_dir" > "$before_dirs"
  snapshot_uninstallers "$install_dir" > "$before_uninstallers"

  log "running GOG installer"
  run_installer "$installer" "$install_dir" "$interactive"

  snapshot_files \
    "$install_dir" \
    "$XDG_DATA_HOME/applications" \
    "$XDG_DATA_HOME/icons" \
    "$HOME/Desktop" > "$after"
  comm -13 "$before" "$after" > "$created" || true
  snapshot_dirs "$install_dir" > "$after_dirs"
  comm -13 "$before_dirs" "$after_dirs" > "$created_dirs" || true
  snapshot_uninstallers "$install_dir" > "$after_uninstallers"
  comm -13 "$before_uninstallers" "$after_uninstallers" > "$created_uninstallers" || true

  if [[ -z "$parent_slug" ]]; then
    uninstaller=$(sed -n '1p' "$created_uninstallers")
    if [[ -z "$uninstaller" ]]; then
      uninstaller=$(find_uninstaller "$install_dir" || true)
    fi
  fi

  write_manifest \
    "$slug" "$name" "$installer" "$install_dir" "$state_dir" "$checksum" \
    "$parent_slug" "$dependency" "$uninstaller"

  if [[ -n "$parent_slug" ]]; then
    refresh_configured_desktop_entries "$parent_slug"
  elif [[ "$compat_profile" == "1" ]]; then
    apply_known_compatibility_profile "$slug"
  fi

  log "installed: $name"
  log "uninstall with: $ARCH_SETUP_ROOT/scripts/gog-game.sh uninstall $slug"
  trap - RETURN
}

list_games() {
  if [[ ! -d "$GOG_STATE_DIR" ]]; then
    log "no GOG games tracked yet"
    return 0
  fi

  local manifest configured found=0
  while IFS= read -r manifest; do
    GOG_PARENT_SLUG=""
    # shellcheck disable=SC1090
    . "$manifest"
    configured=""
    if [[ -f "$(dirname -- "$manifest")/launch.conf" ]]; then
      configured=" [configured launcher]"
    fi
    printf '%-28s %s\n' "$GOG_SLUG" "$GOG_INSTALL_DIR"
    if [[ -n "$GOG_PARENT_SLUG" ]]; then
      printf '  %s [add-on to %s]\n' "$GOG_NAME" "$GOG_PARENT_SLUG"
    else
      printf '  %s%s\n' "$GOG_NAME" "$configured"
    fi
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
  validate_slug "$slug"
  load_manifest "$slug"
  GOG_INSTALL_DIR=$(normalize_install_dir "$GOG_INSTALL_DIR")

  local -a child_addons=()
  if [[ -z "$GOG_PARENT_SLUG" ]]; then
    mapfile -t child_addons < <(find_child_addons "$slug")
    if (( ${#child_addons[@]} > 0 )); then
      die "uninstall add-ons first: ${child_addons[*]}"
    fi
  fi

  confirm_uninstall "$slug" "$yes"

  local state_dir created_file uninstaller uninstall_failed=0
  state_dir=$(state_dir_for_slug "$slug")
  created_file="$state_dir/created-files.txt"

  if [[ -n "$GOG_PARENT_SLUG" ]]; then
    if [[ "$keep_install_dir" != "1" ]]; then
      log "rolling back add-on files from: $GOG_INSTALL_DIR"
      rollback_addon_files "$GOG_INSTALL_DIR" "$state_dir" "$created_file" "$state_dir/created-dirs.txt"
    fi
    remove_tracked_files "$created_file"
    rm -rf -- "$state_dir"
    log "uninstalled add-on metadata for: $slug"
    return 0
  fi

  if [[ "$keep_install_dir" != "1" ]]; then
    uninstaller=$GOG_UNINSTALLER
    if [[ -n "$uninstaller" ]]; then
      case "$uninstaller" in
        "$GOG_INSTALL_DIR"/*) ;;
        *) die "tracked uninstaller is outside the game directory: $uninstaller" ;;
      esac
      [[ -f "$uninstaller" ]] || uninstaller=""
    fi
    if [[ -z "$uninstaller" ]]; then
      uninstaller=$(find_uninstaller "$GOG_INSTALL_DIR" || true)
    fi
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
    configure)
      shift
      configure_game "$@"
      ;;
    launch)
      shift
      launch_game "$@"
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
