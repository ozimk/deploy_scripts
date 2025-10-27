#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"
TARGET_DIR="${TARGET_DIR:-/usr/local/cisco_scripts}"

info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err() { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root"
    exit 1
  fi
}

main() {
  require_root
  if [[ ! -d "$TARGET_DIR" ]]; then
    err "Target dir missing: $TARGET_DIR"
    exit 1
  fi

  info "Setting CISCO_PATH and shell environment"
  cat >/etc/profile.d/cisco.sh <<EOF
# cisco_scripts environment
export CISCO_PATH="$TARGET_DIR"
export PATH="\$CISCO_PATH/bin:\$PATH"
EOF
  chmod 644 /etc/profile.d/cisco.sh

  mkdir -p "$TARGET_DIR/templates" "$TARGET_DIR/networks" "$TARGET_DIR/template_trash"
  chown -R www-data:www-data "$TARGET_DIR/templates" "$TARGET_DIR/networks" "$TARGET_DIR/template_trash"

  if [[ -d "$TARGET_DIR/bin" ]]; then
    find "$TARGET_DIR/bin" -type f -print0 | xargs -0 --no-run-if-empty chmod +x
    info "Marked bin scripts executable"
  fi
}

main "$@"
info "Environment setup step complete"
