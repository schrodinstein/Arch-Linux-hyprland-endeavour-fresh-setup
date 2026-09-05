#!/usr/bin/env bash
set -Eeuo pipefail

ARCH_SETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$ARCH_SETUP_ROOT/scripts/lib/common.sh"

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
bin_dir="$HOME/.local/bin"
softmaker_root="${ARCH_SETUP_SOFTMAKER_ROOT:-$HOME/.local/opt/softmaker-office-nx}"
font_dir="${ARCH_SETUP_MEGAFONT_DIR:-$data_home/fonts/megafont-now-arch-setup}"
work_dir=""
font_stage=""
font_backup=""

cleanup() {
  [[ -z "$work_dir" || ! -d "$work_dir" ]] || rm -rf -- "$work_dir"
  [[ -z "$font_stage" || ! -d "$font_stage" ]] || rm -rf -- "$font_stage"
  if [[ -n "$font_backup" && -d "$font_backup" && ! -e "$font_dir" ]]; then
    mv -- "$font_backup" "$font_dir"
  fi
}
trap cleanup EXIT

newest_download() {
  local pattern=$1
  local candidate newest=""
  local -a matches=()

  shopt -s nullglob
  matches=("$HOME"/Downloads/$pattern)
  shopt -u nullglob

  for candidate in "${matches[@]}"; do
    if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
      newest=$candidate
    fi
  done

  [[ -n "$newest" ]] && printf '%s\n' "$newest"
}

validate_archive_paths() {
  local archive=$1
  local member clean

  while IFS= read -r member; do
    clean=${member#./}
    case "$clean" in
      /*|..|../*|*/..|*/../*) die "unsafe archive member in $archive" ;;
      ""|.|*/) continue ;;
    esac
  done < <(tar -tf "$archive")
}

validate_zip_paths() {
  local archive=$1
  local member clean

  while IFS= read -r member; do
    clean=${member#./}
    case "$clean" in
      /*|..|../*|*/..|*/../*) die "unsafe ZIP member in $archive" ;;
      ""|.|*/) continue ;;
    esac
  done < <(unzip -Z1 "$archive")
}

write_wrapper() {
  local name=$1
  local executable=$2
  local wrapper

  wrapper=$(mktemp)
  {
    printf '#!/usr/bin/env bash\n'
    printf 'exec %q "$@"\n' "$executable"
  } >"$wrapper"
  install -Dm755 "$wrapper" "$bin_dir/$name"
  rm -f -- "$wrapper"
}

install_desktop_files() {
  local current=$1
  local applications="$data_home/applications"
  local icons="$data_home/icons/hicolor/256x256/apps"

  install -Dm644 "$current/icons/tml_256nx.png" \
    "$icons/softmaker-textmaker-nx.png"
  install -Dm644 "$current/icons/pml_256nx.png" \
    "$icons/softmaker-planmaker-nx.png"
  install -Dm644 "$current/icons/prl_256nx.png" \
    "$icons/softmaker-presentations-nx.png"

  mkdir -p "$applications"
  cat >"$applications/softmaker-textmaker-nx.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=TextMaker NX
GenericName=Word Processor
Comment=Create and edit text documents
Exec="$bin_dir/textmakernx" %F
TryExec=$bin_dir/textmakernx
Path=$current
Icon=softmaker-textmaker-nx
Terminal=false
StartupNotify=true
StartupWMClass=tm
Categories=Office;WordProcessor;
MimeType=application/x-tmdx;application/x-tmvx;application/msword;application/rtf;text/rtf;application/vnd.oasis.opendocument.text;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.ms-word.document.macroenabled.12;
EOF

  cat >"$applications/softmaker-planmaker-nx.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=PlanMaker NX
GenericName=Spreadsheet
Comment=Create and edit spreadsheets
Exec="$bin_dir/planmakernx" %F
TryExec=$bin_dir/planmakernx
Path=$current
Icon=softmaker-planmaker-nx
Terminal=false
StartupNotify=true
StartupWMClass=pm
Categories=Office;Spreadsheet;
MimeType=application/x-pmd;application/x-pmdx;application/x-pmv;application/vnd.ms-excel;application/vnd.oasis.opendocument.spreadsheet;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;application/vnd.ms-excel.sheet.macroenabled.12;text/csv;
EOF

  cat >"$applications/softmaker-presentations-nx.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Presentations NX
GenericName=Presentation
Comment=Create and edit presentations
Exec="$bin_dir/presentationsnx" %F
TryExec=$bin_dir/presentationsnx
Path=$current
Icon=softmaker-presentations-nx
Terminal=false
StartupNotify=true
StartupWMClass=pr
Categories=Office;Presentation;
MimeType=application/x-prd;application/x-prdx;application/x-prv;application/vnd.ms-powerpoint;application/vnd.oasis.opendocument.presentation;application/vnd.openxmlformats-officedocument.presentationml.presentation;application/vnd.ms-powerpoint.presentation.macroenabled.12;
EOF

  chmod 644 "$applications"/softmaker-*-nx.desktop
  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate \
      "$applications/softmaker-textmaker-nx.desktop" \
      "$applications/softmaker-planmaker-nx.desktop" \
      "$applications/softmaker-presentations-nx.desktop"
  fi
}

set_document_defaults() {
  local mime

  if ! command -v xdg-mime >/dev/null 2>&1; then
    warn "xdg-mime is unavailable; document defaults were not changed"
    return
  fi
  mkdir -p "$config_home"

  if [[ -f /usr/share/applications/org.kde.okular.desktop ]]; then
    xdg-mime default org.kde.okular.desktop application/pdf
    log "set Okular as the default PDF viewer"
  fi

  [[ -f "$data_home/applications/softmaker-textmaker-nx.desktop" ]] || return 0

  for mime in \
    application/msword \
    application/rtf \
    text/rtf \
    application/vnd.oasis.opendocument.text \
    application/vnd.openxmlformats-officedocument.wordprocessingml.document \
    application/vnd.ms-word.document.macroenabled.12; do
    xdg-mime default softmaker-textmaker-nx.desktop "$mime"
  done

  for mime in \
    application/vnd.ms-excel \
    application/vnd.oasis.opendocument.spreadsheet \
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
    application/vnd.ms-excel.sheet.macroenabled.12 \
    text/csv; do
    xdg-mime default softmaker-planmaker-nx.desktop "$mime"
  done

  for mime in \
    application/vnd.ms-powerpoint \
    application/vnd.oasis.opendocument.presentation \
    application/vnd.openxmlformats-officedocument.presentationml.presentation \
    application/vnd.ms-powerpoint.presentation.macroenabled.12; do
    xdg-mime default softmaker-presentations-nx.desktop "$mime"
  done
  log "set SoftMaker Office NX as the default office suite"
}

install_softmaker() {
  local archive="${ARCH_SETUP_SOFTMAKER_ARCHIVE:-}"
  local archive_hash version release_dir inner special

  if [[ "${ARCH_SETUP_SOFTMAKER:-1}" == 0 ]]; then
    log "skipping SoftMaker Office NX"
    return
  fi

  if [[ -z "$archive" ]]; then
    archive=$(newest_download 'softmaker-office-nx-*-amd64.tgz' || true)
  fi
  if [[ -z "$archive" ]]; then
    warn "SoftMaker archive not found in ~/Downloads; skipping its optional install"
    return
  fi
  [[ -f "$archive" && -r "$archive" ]] || die "SoftMaker archive is not readable: $archive"
  [[ $(uname -m) == x86_64 ]] || die "this SoftMaker archive requires x86_64"

  need_cmd sha256sum
  need_cmd tar
  archive_hash=$(sha256sum "$archive")
  archive_hash=${archive_hash%% *}
  version=${archive##*/}
  version=${version#softmaker-office-nx-}
  version=${version%-amd64.tgz}
  [[ "$version" =~ ^[A-Za-z0-9._-]+$ ]] || version=release
  release_dir="$softmaker_root/$version-${archive_hash:0:12}"

  if [[ -e "$release_dir" ]]; then
    [[ -f "$release_dir/.archive-sha256" ]] || \
      die "refusing to reuse an incomplete SoftMaker directory: $release_dir"
    [[ $(<"$release_dir/.archive-sha256") == "$archive_hash" ]] || \
      die "SoftMaker install hash does not match its source archive"
    log "SoftMaker Office NX $version is already installed"
  else
    log "installing SoftMaker Office NX $version for the current user"
    validate_archive_paths "$archive"
    work_dir=$(mktemp -d)
    mkdir -p "$work_dir/outer" "$work_dir/payload"
    tar --no-same-owner --no-same-permissions -xf "$archive" -C "$work_dir/outer"
    inner="$work_dir/outer/officenx.tar.lzma"
    [[ -f "$inner" ]] || die "SoftMaker payload officenx.tar.lzma was not found"
    validate_archive_paths "$inner"
    tar --no-same-owner --no-same-permissions -xf "$inner" -C "$work_dir/payload"

    special=$(find "$work_dir/payload" ! -type f ! -type d -print -quit)
    [[ -z "$special" ]] || die "SoftMaker payload contains an unsupported special file"
    for inner in textmaker planmaker presentations; do
      [[ -f "$work_dir/payload/$inner" ]] || die "SoftMaker payload is missing $inner"
      chmod 755 "$work_dir/payload/$inner"
    done

    printf '%s\n' "$archive_hash" >"$work_dir/payload/.archive-sha256"
    mkdir -p "$softmaker_root"
    mv -- "$work_dir/payload" "$release_dir"
  fi

  [[ -z "$work_dir" || ! -d "$work_dir" ]] || rm -rf -- "$work_dir"
  work_dir=""

  if [[ -e "$softmaker_root/current" && ! -L "$softmaker_root/current" ]]; then
    backup_file "$softmaker_root/current"
  fi
  ln -sfnT "${release_dir##*/}" "$softmaker_root/current"

  write_wrapper textmakernx "$softmaker_root/current/textmaker"
  write_wrapper planmakernx "$softmaker_root/current/planmaker"
  write_wrapper presentationsnx "$softmaker_root/current/presentations"
  install_desktop_files "$softmaker_root/current"

  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime install --mode user --novendor \
      "$softmaker_root/current/mime/softmaker-office-nx.xml"
  fi
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$data_home/applications"
  log "SoftMaker Office NX integration is ready; activation remains a manual in-app step"
}

install_megafont() {
  local archive="${ARCH_SETUP_MEGAFONT_ARCHIVE:-}"
  local archive_hash current_hash="" extract_dir font relative count=0

  if [[ "${ARCH_SETUP_MEGAFONT:-1}" == 0 ]]; then
    log "skipping MegaFont NOW"
    return
  fi

  if [[ -z "$archive" ]]; then
    archive=$(newest_download 'megafontnow*.zip' || true)
  fi
  if [[ -z "$archive" ]]; then
    warn "MegaFont NOW archive not found in ~/Downloads; skipping its optional install"
    return
  fi
  [[ -f "$archive" && -r "$archive" ]] || die "MegaFont archive is not readable: $archive"

  need_cmd sha256sum
  need_cmd unzip
  archive_hash=$(sha256sum "$archive")
  archive_hash=${archive_hash%% *}
  [[ ! -f "$font_dir/.source-sha256" ]] || current_hash=$(<"$font_dir/.source-sha256")
  if [[ "$current_hash" == "$archive_hash" ]]; then
    log "MegaFont NOW is already installed"
    return
  fi
  if [[ -d "$font_dir" && ! -f "$font_dir/.arch-setup-managed" ]]; then
    die "refusing to replace unmanaged font directory: $font_dir"
  fi

  log "installing MegaFont NOW for the current user"
  validate_zip_paths "$archive"
  work_dir=$(mktemp -d)
  extract_dir="$work_dir/megafont"
  mkdir -p "$extract_dir" "$(dirname -- "$font_dir")"
  unzip -q "$archive" 'fonts/*' -d "$extract_dir"
  [[ -d "$extract_dir/fonts" ]] || die "MegaFont archive does not contain a fonts directory"

  font_stage=$(mktemp -d "$(dirname -- "$font_dir")/.megafont-now.staging.XXXXXX")
  while IFS= read -r -d '' font; do
    relative=${font#"$extract_dir/fonts/"}
    install -Dm644 "$font" "$font_stage/$relative"
    count=$((count + 1))
  done < <(find "$extract_dir/fonts" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
  ((count > 0)) || die "MegaFont archive contained no TTF or OTF files"

  : >"$font_stage/.arch-setup-managed"
  printf '%s\n' "$archive_hash" >"$font_stage/.source-sha256"
  if [[ -d "$font_dir" ]]; then
    font_backup="${font_dir}.previous.$$"
    mv -- "$font_dir" "$font_backup"
  fi
  mv -- "$font_stage" "$font_dir"
  font_stage=""
  if [[ -n "$font_backup" ]]; then
    rm -rf -- "$font_backup"
    font_backup=""
  fi

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$font_dir"
  else
    warn "fc-cache is unavailable; log out and back in before using the fonts"
  fi
  log "installed $count MegaFont NOW font files"
}

ensure_user
install_softmaker
install_megafont
set_document_defaults
