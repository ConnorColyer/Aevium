#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./scripts/set_version.sh <version>"
  echo "Example: ./scripts/set_version.sh 0.1.0"
  exit 1
fi

version="$1"

if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Version must be SemVer format: 0.1.0"
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
build_number=$((major * 10000 + minor * 100 + patch))

config_file="Aevium/Config/AppConfig.xcconfig"

if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file"
  exit 1
fi

perl -0pi -e "s/^MARKETING_VERSION = .*\$/MARKETING_VERSION = ${version}/m" "$config_file"
perl -0pi -e "s/^CURRENT_PROJECT_VERSION = .*\$/CURRENT_PROJECT_VERSION = ${build_number}/m" "$config_file"

echo "Set MARKETING_VERSION=${version}"
echo "Set CURRENT_PROJECT_VERSION=${build_number}"
