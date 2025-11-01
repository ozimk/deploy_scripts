#!/usr/bin/env bash
set -Eeuo pipefail

# -------- CONFIG (override via env if needed) --------
: "${INSTALL_REPO_SLUG:=ozimk/cisco_scripts-deployment}"   # public app repo by default
: "${TARGET_DIR:=/usr/local/cisco_scripts}"                # install prefix
: "${PHP_STREAM:=8.2}"                                     # 8.1 or 8.2
# ------------------------------------------------------

LOG_FILE="/var/log/cisco_scripts_install.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
log()  { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then err "Must run as root"; exit 1; fi
}

main() {
  require_root
  : >"$LOG_FILE" || true
  bold "=== Cisco Scripts: RHEL installation ==="

  # 1) Packages, repos, PHP module, firewalld, httpd, php-fpm, gh, composer
  PHP_STREAM="$PHP_STREAM" bash "$SCRIPT_DIR/install_packages.sh" 2>&1 | tee -a "$LOG_FILE"

  # 2) Clone app repo
  INSTALL_REPO_SLUG="$INSTALL_REPO_SLUG" TARGET_DIR="$TARGET_DIR"         bash "$SCRIPT_DIR/clone_cisco_scripts.sh" 2>&1 | tee -a "$LOG_FILE"

  # 3) Env vars
  TARGET_DIR="$TARGET_DIR" bash "$SCRIPT_DIR/set_environment.sh" 2>&1 | tee -a "$LOG_FILE"

  # 4) Apache (httpd) + PHP‑FPM + SELinux + firewall
  TARGET_DIR="$TARGET_DIR" bash "$SCRIPT_DIR/setup_apache.sh" 2>&1 | tee -a "$LOG_FILE"

  bold "=== Install complete ==="
  log  "Open: http://localhost/ (or your server IP)"
  log  "New shells will load CISCO_PATH automatically. For current shell: source /etc/profile.d/cisco.sh"
}

main "$@"
