#!/usr/bin/env bash
set -Eeuo pipefail
export INSTALL_REPO_URL="https://github.com/ozimk/cisco_scripts-deployment.git"

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
  apt-get update -y || true

  info "Installing base packages (apache2, php, extensions, git, dialog)"
  # IMPROVEMENT: Removed '|| true' on essential packages to ensure installation success
  apt-get install -y \
    apache2 php libapache2-mod-php php-curl php-ssh2 \
    git dialog

  # Non-essential packages can still use '|| true' if we want to proceed without them
  apt-get install -y open-vm-tools open-vm-tools-desktop || true

  if ! command -v gh >/dev/null 2>&1; then
    info "Installing GitHub CLI (gh) via apt if possible"
    if apt-cache policy gh | grep -q Candidate; then
      apt-get install -y gh || true
    fi
  fi

  if ! command -v gh >/dev/null 2>&1; then
    if command -v snap >/dev/null 2>&1; then
      info "Installing GitHub CLI (gh) via snap fallback"
      snap install gh --classic || warn "Snap install of gh failed; proceeding without gh"
    else
      warn "Snap not available; skipping gh"
    fi
  fi

  info "Enabling Apache on boot"
  systemctl enable apache2 || true
}

verify_php_mod() {
  info "Ensuring Apache PHP module is enabled"
  if ! apache2ctl -M 2>/dev/null | grep -qi 'php'; then
    a2enmod php* || true
    systemctl restart apache2 || true
  fi
}

require_root
install_packages
verify_php_mod
info "Package installation step complete"
