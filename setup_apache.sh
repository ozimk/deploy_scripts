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

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" && ! -L "$path" ]]; then
    local bak="${path}.bak"
    if [[ ! -e "$bak" ]]; then
      cp -a "$path" "$bak"
      info "Backed up $path to $bak"
    else
      info "Backup already exists: $bak"
    fi
  fi
}

main() {
  require_root

  if [[ -d "/var/www/html" || -L "/var/www/html" ]]; then
    if [[ ! -L "/var/www/html" ]]; then
      backup_if_exists "/var/www/html"
      rm -rf /var/www/html
    else
      rm -f /var/www/html
    fi
  fi
  ln -s "$TARGET_DIR/html" /var/www/html
  info "Linked /var/www/html -> $TARGET_DIR/html"

  if [[ -f "$TARGET_DIR/apache2.conf" ]]; then
    backup_if_exists "/etc/apache2/apache2.conf"
    ln -sf "$TARGET_DIR/apache2.conf" /etc/apache2/apache2.conf
    info "Symlinked Apache config to repo's apache2.conf"
  else
    warn "Repo apache2.conf not found; using system default"
  fi

  if ! apache2ctl -M 2>/dev/null | grep -qi 'php'; then
    a2enmod php* || true
  fi

  systemctl restart apache2
  systemctl enable apache2 || true
  info "Apache restarted and enabled"
}

main "$@"
info "Apache setup step complete"
