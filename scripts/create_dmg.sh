#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ./scripts/create_dmg.sh <Aevium.app> <output.dmg>"
  exit 1
fi

app_path="$1"
output_path="$2"

if [[ ! -d "$app_path" ]]; then
  echo "Missing app bundle at $app_path"
  exit 1
fi

rm -f "$output_path"
mkdir -p "$(dirname "$output_path")"

staging_dir="$(mktemp -d)"
trap 'rm -rf "$staging_dir"' EXIT

cp -R "$app_path" "$staging_dir/"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
  -volname "Aevium" \
  -srcfolder "$staging_dir" \
  -ov \
  -format UDZO \
  "$output_path" >/dev/null

echo "Created $output_path"
