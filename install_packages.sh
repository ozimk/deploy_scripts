#!/usr/bin/env bash
set -Eeuo pipefail

: "${PHP_STREAM:=8.2}"

LOG_FILE="/var/log/cisco_scripts_install.log"
log()  { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { err "Must run as root"; exit 1; }; }

os_id()       { . /etc/os-release; echo "$ID"; }
os_version()  { . /etc/os-release; echo "${VERSION_ID%%.*}"; }

main() {
  require_root
  local id ver arch
  id="$(os_id)"; ver="$(os_version)"; arch="$(/bin/arch)"
  log "Detected OS: $id $ver ($arch)"

  dnf -y install dnf-plugins-core || true

  # Enable CRB/CodeReady/PowerTools as appropriate
  case "$id" in
    rhel)
      if command -v subscription-manager >/dev/null 2>&1; then
        subscription-manager repos --enable "codeready-builder-for-rhel-${ver}-$(arch)-rpms" || warn "Could not enable CodeReady (maybe already enabled)"
      fi
      ;;
    rocky|almalinux|centos|centosstream|centos-stream)
      dnf config-manager --set-enabled crb || warn "CRB enable failed (maybe already enabled)"
      ;;
    fedora)
      : # not needed
      ;;
    *) warn "Unknown OS ID '$id' - continuing"
      ;;
  esac

  # EPEL (best effort)
  if ! rpm -q epel-release >/dev/null 2>&1; then
    if [[ "$id" == "rhel" ]]; then
      dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${ver}.noarch.rpm" || warn "EPEL install failed"
    else
      dnf -y install epel-release || warn "EPEL install failed"
    fi
  fi

  # GitHub CLI repo (for `gh`)
  if ! dnf repolist | grep -qi github-cli; then
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo || warn "Adding gh repo failed"
  fi

  # PHP module stream (RHEL 9 provides php:8.1/8.2)
  if dnf -y module list php >/dev/null 2>&1; then
    dnf -y module reset php || true
    dnf -y module enable "php:${PHP_STREAM}" || warn "Could not enable php:${PHP_STREAM}"
    dnf -y module install "php:${PHP_STREAM}" || true
  fi

  # Core packages
  dnf -y install         git curl jq unzip         httpd php php-cli php-fpm php-common php-mbstring php-xml php-bcmath php-pdo php-mysqlnd         policycoreutils-python-utils firewalld         gh composer || true

  # Composer fallback (if RPM missing)
  if ! command -v composer >/dev/null 2>&1; then
    log "Installing Composer via installer"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm -f composer-setup.php
  fi

  systemctl enable --now firewalld || true
  firewall-cmd --permanent --add-service=http  || true
  firewall-cmd --permanent --add-service=https || true
  firewall-cmd --reload || true

  systemctl enable --now php-fpm || true
  systemctl enable --now httpd   || true

  log "Base packages installed."
}

main "$@"
