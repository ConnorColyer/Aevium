#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ./scripts/generate_release_notes.sh <version> <output.md>"
  exit 1
fi

version="$1"
output_path="$2"
current_tag="v${version}"
previous_tag="$(git tag --list 'v*' --sort=-version:refname | grep -vx "$current_tag" | head -n 1 || true)"

mkdir -p "$(dirname "$output_path")"

{
  echo "# Aevium ${version}"
  echo

  if [[ -n "$previous_tag" ]]; then
    changes="$(git log --format='- %s' "${previous_tag}..HEAD")"
    if [[ -n "$changes" ]]; then
      echo "$changes"
    else
      echo "- Maintenance release."
    fi
  else
    echo "- Initial release."
  fi
} > "$output_path"

echo "Wrote $output_path"
