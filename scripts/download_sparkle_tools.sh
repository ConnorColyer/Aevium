#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ./scripts/download_sparkle_tools.sh <sparkle-version> <output-dir>"
  exit 1
fi

version="$1"
output_dir="$2"
archive_path="${output_dir}/Sparkle-${version}.tar.xz"

rm -rf "$output_dir"
mkdir -p "$output_dir"

curl -L "https://github.com/sparkle-project/Sparkle/releases/download/${version}/Sparkle-${version}.tar.xz" \
  -o "$archive_path"

tar -xf "$archive_path" -C "$output_dir"

tools_dir="$(find "$output_dir" -type d -path "*/bin" | head -n 1 || true)"
if [[ -z "$tools_dir" ]]; then
  echo "Could not locate Sparkle bin directory in $output_dir" >&2
  exit 1
fi

echo "$tools_dir"
