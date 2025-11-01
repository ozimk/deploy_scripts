#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"
TARGET_DIR="${TARGET_DIR:-/usr/local/cisco_scripts}"
# This variable comes from install.sh
INSTALL_REPO_SLUG="${INSTALL_REPO_SLUG:?INSTALL_REPO_SLUG not set}"

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

  local repo_url=""
  # Check if the slug already looks like a full URL
  if [[ "$INSTALL_REPO_SLUG" == http* ]]; then
    repo_url="$INSTALL_REPO_SLUG"
  else
    # Build the URL from the slug (e.g., ozimk/cisco_scripts-deployment)
    repo_url="https://github.com/${INSTALL_REPO_SLUG}.git"
  fi

  info "Cloning public repo $repo_url into $TARGET_DIR ..."
  
  # Just use git clone. No 'gh' needed.
  if ! git clone "$repo_url" "$TARGET_DIR"; then
    err "Failed to clone public repository. Check URL: $repo_url"
    exit 1
  fi
  
  info "Clone complete."
}

main "$@"
