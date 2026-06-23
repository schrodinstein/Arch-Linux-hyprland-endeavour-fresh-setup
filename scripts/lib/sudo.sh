#!/usr/bin/env bash

TEMP_SUDOERS_FILE="${ARCH_SETUP_TEMP_SUDOERS_FILE:-/etc/sudoers.d/90-arch-setup-temp}"
TEMP_SUDO_INSTALLED=0

sudo_keepalive_pid=""

start_sudo_keepalive() {
  while true; do
    sudo -n true 2>/dev/null || true
    sleep 60
  done &
  sudo_keepalive_pid=$!
}

stop_sudo_keepalive() {
  if [[ -n "$sudo_keepalive_pid" ]]; then
    kill "$sudo_keepalive_pid" 2>/dev/null || true
    wait "$sudo_keepalive_pid" 2>/dev/null || true
    sudo_keepalive_pid=""
  fi
}

install_temp_sudo() {
  if [[ "${ARCH_SETUP_TEMP_SUDO:-1}" != "1" ]]; then
    log "temporary sudoers rule disabled"
    sudo -v
    start_sudo_keepalive
    return 0
  fi

  log "requesting sudo once and installing temporary NOPASSWD sudoers rule"
  sudo -v

  local current_user
  current_user=$(id -un)
  local tmp
  tmp=$(mktemp)
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$current_user" > "$tmp"

  sudo install -m 0440 "$tmp" "$TEMP_SUDOERS_FILE"
  rm -f "$tmp"

  if ! sudo visudo -cf "$TEMP_SUDOERS_FILE" >/dev/null; then
    sudo rm -f "$TEMP_SUDOERS_FILE"
    die "temporary sudoers file failed validation"
  fi

  TEMP_SUDO_INSTALLED=1
}

revoke_temp_sudo() {
  stop_sudo_keepalive
  if [[ "$TEMP_SUDO_INSTALLED" == "1" ]]; then
    log "revoking temporary sudoers rule"
    sudo rm -f "$TEMP_SUDOERS_FILE" || true
  fi
  sudo -k || true
}

