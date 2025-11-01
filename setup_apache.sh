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
    if ! systemctl restart httpd; then
        err "Failed to start httpd.service. Run 'systemctl status httpd.service' or 'journalctl -xe' for details."
        exit 1
    fi
    systemctl enable httpd || true
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

  
  info "Creating new, compatible Apache config at /etc/httpd/conf.d/cisco-scripts.conf"
  
  # We create a new config file with *only* the settings we need.
  cat > /etc/httpd/conf.d/cisco-scripts.conf <<'EOF'
#
# Custom config for Cisco Scripts
#
# This file is created by the setup_apache.sh script
# to apply the settings from the repo's apache2.conf
# in a way that is compatible with RHEL's httpd.
#

# Set the web root directory permissions and options
<Directory /var/www/html/>
    SetEnv CISCO_PATH "/usr/local/cisco_scripts"
    DirectoryIndex index.php
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

# We also need to fix the permissions for the /var/www directory itself
# to allow the FollowSymLinks option.
<Directory /var/www>
    AllowOverride None
    Require all granted
</Directory>
EOF

  info "Attempting to restart Apache (httpd)..."
  if ! systemctl restart httpd; then
      err "Failed to start httpd.service. This is unexpected."
      err "Please run 'systemctl status httpd.service' or 'journalctl -xe' to see the exact error."
      exit 1
  fi
  
  systemctl enable httpd || true
  info "Apache (httpd) restarted and enabled"
}

main "$@"
