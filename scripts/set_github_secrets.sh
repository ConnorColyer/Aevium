#!/usr/bin/env bash

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install it and run 'gh auth login' first."
  exit 1
fi

repo="${1:-}"
if [[ -z "$repo" ]]; then
  repo="$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\\.git$##')"
fi

if [[ -z "$repo" ]]; then
  echo "Could not determine GitHub repository. Pass it explicitly as owner/repo."
  exit 1
fi

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "$path" ]]; then
    echo "Missing $label at $path"
    exit 1
  fi
}

secrets_dir="${AEVIUM_SECRETS_DIR:-$HOME/.config/aevium/secrets}"
sparkle_private_key_b64="${SPARKLE_PRIVATE_KEY_BASE64_FILE:-$secrets_dir/SPARKLE_PRIVATE_KEY_BASE64.txt}"

require_file "$sparkle_private_key_b64" "SPARKLE_PRIVATE_KEY_BASE64 file"

gh secret set SPARKLE_PRIVATE_KEY_BASE64 --repo "$repo" < "$sparkle_private_key_b64"

echo "GitHub Sparkle secret updated for $repo"
