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

  rm -f /etc/apt/sources.list.d/github-cli.list /etc/apt/keyrings/githubcli-archive-keyring.gpg || true

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list

  apt-get update -y
  apt-get install -y gh
}

install_base_packages() {
  export DEBIAN_FRONTEND=noninteractive
  info "Updating apt package index"
  apt-get update -y

  info "Installing core packages (apache2, php, git, dialog)"
  apt-get install -y apache2 php libapache2-mod-php php-curl php-ssh2 git dialog curl gpg

  info "Enabling Apache PHP module and service"
  a2enmod php* >/dev/null 2>&1 || true
  systemctl enable apache2 || true
  systemctl restart apache2 || true
}

require_root
install_base_packages
install_github_cli
info "Package installation step complete"
