#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/cisco_scripts_install.log"
TARGET_DIR="${TARGET_DIR:-/usr/local/cisco_scripts}"
INSTALL_REPO_URL="${INSTALL_REPO_URL:-}"

info() { printf "[INFO] %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "[WARN] %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "[ERROR] %s\n" "$*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Must run as root"
    exit 1
  fi
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

place_from_local() {
  info "Placing code from local repo: $repo_root -> $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  rsync -a --delete \
    --exclude 'deploy/' \
    "$repo_root"/ "$TARGET_DIR"/
}

try_gh_clone() {
  local url="$1"
  if ! command -v gh >/dev/null 2>&1; then
    warn "GitHub CLI not found; skipping GitHub clone"
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    info "GitHub not authenticated; starting login flow..."
    gh auth login || {
      warn "GitHub authentication failed or cancelled."
      return 1
    }
  fi

  info "Cloning via GitHub CLI: $url"
  gh repo clone "$url" "$TARGET_DIR" || return 1
  return 0
}


try_git_https_clone() {
  local url="$1"
  if ! command -v git >/dev/null 2>&1; then
    err "git not found; cannot clone from $url"
    return 1
  fi
  info "Cloning via git HTTPS: $url"
  git clone "$url" "$TARGET_DIR"
}

main() {
  require_root

  # IMPROVEMENT: Ensure a clean slate before attempting installation
  if [[ -d "$TARGET_DIR" && -n "$(ls -A "$TARGET_DIR" 2>/dev/null || true)" ]]; then
    info "Target directory is non-empty. Removing $TARGET_DIR for a clean install."
    rm -rf "$TARGET_DIR"
  fi

  mkdir -p "$TARGET_DIR"
  # Note: The rmdir call is no longer necessary here since we use rm -rf above.

  if [[ -n "$INSTALL_REPO_URL" ]]; then
    if [[ "$INSTALL_REPO_URL" =~ ^https?://github\.com/([^/]+/[^/.]+)(\.git)?$ ]]; then
      owner_repo="${BASH_REMATCH[1]}"
      if try_gh_clone "$owner_repo"; then
        info "Clone via gh successful"
        return 0
      fi
    fi
    if try_git_https_clone "$INSTALL_REPO_URL"; then
      info "Clone via git successful"
      return 0
    fi
    warn "Remote clone failed; falling back to local placement"
    place_from_local
  else
    place_from_local
  fi
}

main "$@"
info "Code placement step complete"
