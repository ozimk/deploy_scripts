#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"
TARGET_DIR="${TARGET_DIR:-/usr/local/cisco_scripts}"
INSTALL_REPO_SLUG="${INSTALL_REPO_SLUG:?INSTALL_REPO_SLUG not set (e.g. ozimk/cisco_scripts-deployment)}"

info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root"; exit 1
  fi
}

main() {
  require_root

  if [[ -d "$TARGET_DIR" && -n "$(ls -A "$TARGET_DIR" 2>/dev/null || true)" ]]; then
    info "Target dir already exists and is non-empty; skipping clone: $TARGET_DIR"
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    err "GitHub CLI (gh) is required to clone private repo $INSTALL_REPO_SLUG. Install gh and re-run."
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    info "GitHub not authenticated; starting device + browser login..."
    # Use web flow (device code). Works in GUI or SSH.
    gh auth login --hostname github.com --web || {
      err "GitHub authentication failed or was cancelled."
      exit 1
    }
  else
    info "GitHub already authenticated."
  fi

  info "Cloning $INSTALL_REPO_SLUG into $TARGET_DIR ..."
  gh repo clone "$INSTALL_REPO_SLUG" "$TARGET_DIR"
  info "Clone complete."
}

main "$@"
