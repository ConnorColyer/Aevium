#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./scripts/sparkle_tool.sh <tool-name>"
  exit 1
fi

tool_name="$1"

if [[ -n "${AEVIUM_SPARKLE_TOOLS_DIR:-}" ]]; then
  candidate="${AEVIUM_SPARKLE_TOOLS_DIR}/${tool_name}"
  if [[ -x "$candidate" ]]; then
    echo "$candidate"
    exit 0
  fi
fi

search_roots=(
  "${PWD}/.build/SourcePackages"
  "${PWD}/SourcePackages"
  "${HOME}/Library/Developer/Xcode/DerivedData"
)

for root in "${search_roots[@]}"; do
  [[ -d "$root" ]] || continue

  candidate="$(find "$root" -type f -path "*/Sparkle/bin/${tool_name}" | head -n 1 || true)"
  if [[ -n "$candidate" ]]; then
    echo "$candidate"
    exit 0
  fi
done

echo "Could not find Sparkle tool '${tool_name}'. Resolve packages first with xcodebuild -resolvePackageDependencies." >&2
exit 1
