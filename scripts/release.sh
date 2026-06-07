#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 0.1.0"
  exit 1
fi

version="$1"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be SemVer format: 0.1.0"
  exit 1
fi

tag="v${version}"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit or stash changes before releasing."
  exit 1
fi

git fetch origin --tags

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  echo "Tag ${tag} already exists."
  exit 1
fi

./scripts/set_version.sh "$version"
git add Aevium/Config/AppConfig.xcconfig

if ! git diff --cached --quiet; then
  git commit -m "Release ${tag}"
fi

git push origin main
git tag -a "${tag}" -m "Release ${tag}"
git push origin "${tag}"

echo "Released ${tag}. GitHub Actions will build the standalone app artifacts, publish the release, and refresh the Sparkle appcast."
