#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"

info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root"; exit 1
  fi
}

apt_cleanup_bad_gh_source() {
  local bad="/etc/apt/sources.list.d/archive_uri-https_cli_github_com_packages-noble.list"
  if [[ -f "$bad" ]]; then
    warn "Removing broken GitHub CLI apt source ($bad)"
    rm -f "$bad"
  fi
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt_cleanup_bad_gh_source
  info "Updating apt package index"
  apt-get update -y

  info "Installing base packages (apache2, php, extensions, git, dialog, gh if available)"
  apt-get install -y \
    apache2 php libapache2-mod-php php-curl php-ssh2 \
    git dialog || true

  # Try to install GitHub CLI from apt if present (no snap)
  if ! command -v gh >/dev/null 2>&1; then
    if apt-cache policy gh | grep -q Candidate; then
      apt-get install -y gh || warn "Failed to install gh from APT; you may need to install gh manually."
    else
      warn "gh not available from APT on this system; please install GitHub CLI manually if needed."
    fi
  fi

  info "Enabling Apache on boot"
  systemctl enable apache2 || true

  info "Ensuring Apache PHP module is enabled"
  if ! apache2ctl -M 2>/dev/null | grep -qi 'php'; then
    a2enmod php* || true
    systemctl restart apache2 || true
  else
    systemctl restart apache2 || true
  fi
}

require_root
install_packages
info "Package installation step complete"
