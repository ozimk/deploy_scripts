#!/usr/bin/env bash
set -Eeuo pipefail

# -------- CONFIG you should set --------
export INSTALL_REPO_SLUG="${INSTALL_REPO_SLUG:-https://github.com/ozimk/cisco_scripts-deployment}"
export TARGET_DIR="${TARGET_DIR:-/usr/local/cisco_scripts}"
# ---------------------------------------

LOG_FILE="/var/log/cisco_scripts_install.log"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "This installer must run as root. Try: sudo $0"
    exit 1
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

normalize_line_endings() {
  info "Normalizing line endings in deploy scripts"
  if ! command -v dos2unix >/dev/null 2>&1; then
    info "dos2unix not found, attempting to install..."
    if ! dnf install -y dos2unix; then
      err "Failed to install dos2unix. Please install it manually and re-run."
      exit 1
    fi
    info "dos2unix installed successfully."
  fi
  
  find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.sh" -exec dos2unix {} \; >/dev/null 2>&1 || true
  chmod +x "$SCRIPT_DIR"/*.sh
  info "Line endings normalized and scripts made executable."
}

trap 'err "Installer failed (line $LINENO). See $LOG_FILE for details."' ERR

main() {
  require_root
  mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"; chmod 644 "$LOG_FILE"

  bold "=== cisco_scripts installer ==="
  info "Logging to: $LOG_FILE"
  info "Script dir: $SCRIPT_DIR"
  info "Target dir: $TARGET_DIR"
  info "Repo slug : $INSTALL_REPO_SLUG"

  normalize_line_endings

  bash "$SCRIPT_DIR/install_packages.sh" 2>&1 | tee -a "$LOG_FILE"

  INSTALL_REPO_SLUG="$INSTALL_REPO_SLUG" TARGET_DIR="$TARGET_DIR" \
    bash "$SCRIPT_DIR/clone_cisco_scripts.sh" 2>&1 | tee -a "$LOG_FILE"

  TARGET_DIR="$TARGET_DIR" bash "$SCRIPT_DIR/set_environment.sh" 2>&1 | tee -a "$LOG_FILE"

  TARGET_DIR="$TARGET_DIR" bash "$SCRIPT_DIR/setup_apache.sh" 2>&1 | tee -a "$LOG_FILE"

  bold "=== Install complete ==="
  info "Open: http://localhost/"
  info "New shells will load CISCO_PATH automatically. For this shell: source /etc/profile.d/cisco.sh"
}

main "$@"
