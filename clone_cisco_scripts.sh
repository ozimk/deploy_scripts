#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"
: "${TARGET_DIR:=/usr/local/cisco_scripts}"
: "${INSTALL_REPO_SLUG:=ozimk/cisco_scripts-deployment}"
: "${BRANCH:=main}"

log()  { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { err "Must run as root"; exit 1; }; }

try_public_clone() {
  local url="https://github.com/${INSTALL_REPO_SLUG}.git"
  log "Trying public HTTPS clone: $url (branch=$BRANCH)"
  if git ls-remote --exit-code "$url" &>/dev/null; then
    git clone --depth 1 --branch "$BRANCH" "$url" "$TARGET_DIR"
    return 0
  fi
  return 1
}

try_token_clone() {
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  [[ -n "$token" ]] || return 1
  local url="https://${token}@github.com/${INSTALL_REPO_SLUG}.git"
  log "Trying token-based clone via HTTPS (branch=$BRANCH)"
  git clone --depth 1 --branch "$BRANCH" "$url" "$TARGET_DIR"
}

try_gh_clone() {
  command -v gh >/dev/null 2>&1 || return 1
  if ! gh auth status >/dev/null 2>&1; then
    log "gh not authenticated; attempting web login (only needed for private repos)."
    gh auth login --hostname github.com --web || return 1
  fi
  log "Trying gh clone (branch=$BRANCH)"
  gh repo clone "$INSTALL_REPO_SLUG" "$TARGET_DIR" -- --branch "$BRANCH" --depth 1
}

main() {
  require_root
  mkdir -p "$TARGET_DIR"

  # Prefer PUBLIC unauthenticated clone first now that the repo is public.
  if try_public_clone; then
    :
  elif try_token_clone; then
    :
  elif try_gh_clone; then
    :
  else
    err "Failed to clone repo. Ensure the repo exists and is public, or provide GH_TOKEN/gh auth."
    exit 1
  fi
  log "Clone complete: $TARGET_DIR"
}

main "$@"
