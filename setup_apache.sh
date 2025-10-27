#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"
TARGET_DIR="${TARGET_DIR:-/usr/local/cisco_scripts}"

info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root"; exit 1
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

  # Use a standard web root inside repo: prefer html/, else web/
  local webroot=""
  if [[ -d "$TARGET_DIR/html" ]]; then
    webroot="$TARGET_DIR/html"
  elif [[ -d "$TARGET_DIR/web" ]]; then
    webroot="$TARGET_DIR/web"
  else
    warn "No html/ or web/ directory found under $TARGET_DIR. Apache will serve default page."
    systemctl restart apache2
    return 0
  fi

  # Point /var/www/html at the repo’s web root
  if [[ -d "/var/www/html" || -L "/var/www/html" ]]; then
    if [[ ! -L "/var/www/html" ]]; then
      backup_if_exists "/var/www/html"
      rm -rf /var/www/html
    else
      rm -f /var/www/html
    fi
  fi
  ln -s "$webroot" /var/www/html
  info "Linked /var/www/html -> $webroot"

  # If the repo provides apache2.conf, symlink it (optional)
  if [[ -f "$TARGET_DIR/apache2.conf" ]]; then
    backup_if_exists "/etc/apache2/apache2.conf"
    ln -sf "$TARGET_DIR/apache2.conf" /etc/apache2/apache2.conf
    info "Symlinked Apache config to repo's apache2.conf"
  fi

  systemctl restart apache2
  systemctl enable apache2 || true
  info "Apache restarted and enabled"
}

main "$@"
