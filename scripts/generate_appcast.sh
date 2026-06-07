#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: ./scripts/generate_appcast.sh <version> <archive> <release-notes.md> <output.xml>"
  exit 1
fi

version="$1"
archive_path="$2"
release_notes_path="$3"
output_path="$4"

if [[ ! -f "$archive_path" ]]; then
  echo "Missing archive at $archive_path"
  exit 1
fi

if [[ ! -f "$release_notes_path" ]]; then
  echo "Missing release notes at $release_notes_path"
  exit 1
fi

repo_slug="${GITHUB_REPOSITORY:-}"
if [[ -z "$repo_slug" ]]; then
  remote_url="$(git remote get-url origin)"
  repo_slug="$(printf '%s\n' "$remote_url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

if [[ ! "$repo_slug" =~ .+/.+ ]]; then
  echo "Could not determine GitHub repository slug."
  exit 1
fi

build_version="$(awk -F' = ' '/^CURRENT_PROJECT_VERSION = / { print $2 }' Aevium/Config/AppConfig.xcconfig)"
if [[ -z "$build_version" ]]; then
  echo "Could not read CURRENT_PROJECT_VERSION from Aevium/Config/AppConfig.xcconfig"
  exit 1
fi

sign_update_tool="$(./scripts/sparkle_tool.sh sign_update)"
sign_update_args=()
if [[ -n "${AEVIUM_SPARKLE_PRIVATE_KEY_PATH:-}" ]]; then
  if [[ ! -f "${AEVIUM_SPARKLE_PRIVATE_KEY_PATH}" ]]; then
    echo "Missing Sparkle private key at ${AEVIUM_SPARKLE_PRIVATE_KEY_PATH}"
    exit 1
  fi

  sign_update_args+=(--ed-key-file "${AEVIUM_SPARKLE_PRIVATE_KEY_PATH}")
fi

signature_fragment="$("$sign_update_tool" "${sign_update_args[@]}" "$archive_path")"
release_page_url="https://github.com/${repo_slug}/releases/tag/v${version}"
download_url="https://github.com/${repo_slug}/releases/download/v${version}/$(basename "$archive_path")"
pub_date="$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")"
release_notes="$(sed 's/]]>/]]]]><![CDATA[>/g' "$release_notes_path")"

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Aevium</title>
    <link>https://github.com/${repo_slug}/releases</link>
    <description>Latest Aevium release feed.</description>
    <language>en</language>
    <item>
      <title>Version ${version}</title>
      <link>${release_page_url}</link>
      <sparkle:version>${build_version}</sparkle:version>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0.0</sparkle:minimumSystemVersion>
      <pubDate>${pub_date}</pubDate>
      <description sparkle:format="markdown"><![CDATA[
${release_notes}
]]></description>
      <enclosure url="${download_url}"
                 ${signature_fragment}
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Wrote $output_path"
