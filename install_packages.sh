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

install_github_cli() {
  if command -v gh >/dev/null 2>&1; then
    info "GitHub CLI already installed"
    return 0
  fi

  info "Installing GitHub CLI (gh)..."

  # Add the official GitHub CLI repository
  if ! dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo; then
    err "Failed to add GitHub CLI repository"
    exit 1
  fi

  # Install gh
  dnf install -y gh
}

install_base_packages() {
  info "Installing prerequisite: dnf-plugins-core (for config-manager)"
  dnf install -y dnf-plugins-core

  info "Enabling EPEL repository (for php-pecl-ssh2)"
  dnf install -y epel-release || warn "Could not install epel-release. This is OK if on Fedora."

  info "Installing core packages (httpd, php, git, dialog)"
  dnf install -y httpd php php-curl php-pecl-ssh2 git dialog curl gpg

  info "Enabling Apache (httpd) service"
  systemctl enable httpd || true
  systemctl restart httpd || true
}

require_root
install_base_packages
install_github_cli
info "Package installation step complete"
