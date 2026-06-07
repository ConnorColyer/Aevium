#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ./scripts/create_zip.sh <Aevium.app> <output.zip>"
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

ditto -c -k --keepParent "$app_path" "$output_path"

echo "Created $output_path"
