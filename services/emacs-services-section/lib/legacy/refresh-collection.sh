#!/usr/bin/env bash
# Refresh the Emacs legacy preservation collection without changing its sources.
set -euo pipefail

collection_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_repository="${EMACS_LEGACY_SOURCE_REPOSITORY:-}"
if [[ -z "$source_repository" ]]; then
  printf 'Set EMACS_LEGACY_SOURCE_REPOSITORY to the source workspace.\n' >&2
  exit 1
fi
archive_source="$source_repository/lib/emsenn/services/561-group/services/red-cup-engineering/src/content/assets/legacy/2026-06-17-archive.emsenn.net"
home_source="${HOME}/.emacs.d"

if [[ ! -d "$archive_source" || ! -d "$home_source" ]]; then
  printf 'Required legacy source is unavailable.\n' >&2
  exit 1
fi

mkdir -p "$collection_dir/archive.emsenn.net-2026-06-17" \
  "$collection_dir/home-emacs.d/straight/versions"

# Preserve every historical pathname; excluded external references are vendored
# third-party fixtures rather than prior Emacs work product.
while IFS= read -r -d '' source_file; do
  relative_path="${source_file#"$archive_source"/}"
  target_file="$collection_dir/archive.emsenn.net-2026-06-17/$relative_path"
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
done < <(find "$archive_source" -type f \
  \( -ipath '*emacs*' -o -iname '*gnoponemacs*' \) \
  -not -ipath '*/external-references/*' -print0)

# Keep all top-level user files, plus the dependency lockfile; omit downloaded
# package repositories, generated build output, and compiled caches.
while IFS= read -r -d '' source_file; do
  relative_path="${source_file#"$home_source"/}"
  target_file="$collection_dir/home-emacs.d/$relative_path"
  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
done < <(find "$home_source" -maxdepth 1 -type f -print0)

if [[ -f "$home_source/straight/versions/default.el" ]]; then
  cp -a "$home_source/straight/versions/default.el" \
    "$collection_dir/home-emacs.d/straight/versions/default.el"
fi

manifest_file="$collection_dir/MANIFEST.tsv"
temporary_manifest="$(mktemp)"
trap 'rm -f "$temporary_manifest"' EXIT
{
  printf 'collection-path\tsource\tsha256\tbytes\n'
  while IFS= read -r -d '' collected_file; do
    relative_path="${collected_file#"$collection_dir"/}"
    source_path='home-emacs.d snapshot'
    if [[ "$relative_path" == archive.emsenn.net-2026-06-17/* ]]; then
      source_path="$archive_source/${relative_path#archive.emsenn.net-2026-06-17/}"
    elif [[ "$relative_path" == network-github/* ]]; then
      source_path='GitHub capture; see network-github/NETWORK-SOURCES.md'
    fi
    printf '%s\t%s\t%s\t%s\n' "$relative_path" "$source_path" \
      "$(sha256sum "$collected_file" | awk '{print $1}')" \
      "$(wc -c < "$collected_file" | tr -d ' ')"
  done < <(find "$collection_dir/archive.emsenn.net-2026-06-17" \
    "$collection_dir/home-emacs.d" "$collection_dir/network-github" \
    "$collection_dir/network-cold-red-gate" \
    -type f -print0 2>/dev/null | sort -z)
} > "$temporary_manifest"
mv "$temporary_manifest" "$manifest_file"

printf 'Legacy Emacs collection refreshed at %s\n' "$collection_dir"
