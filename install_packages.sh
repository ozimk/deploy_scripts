#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"

info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root"
    exit 1
  fi
}

install_base_packages() {
  info "Enabling EPEL repository (for php-pecl-ssh2)"
  dnf install -y epel-release || warn "Could not install epel-release. This is OK if on Fedora."

  info "Installing core packages (httpd, php, git, dialog)"
  # No 'gh' or 'gnupg2' needed since it's a public repo
  dnf install -y httpd php php-curl php-pecl-ssh2 git dialog curl

  info "Enabling Apache (httpd) service"
  systemctl enable httpd || true
  systemctl restart httpd || true
}

require_root
install_base_packages
info "Package installation step complete"
