#!/usr/bin/env bash
# Merge the per-platform images (pushed by digest) into one multi-arch tag set,
# then print the digest of the merged index.
#
# Usage: merge-image.sh <digests-dir>   (one empty file per platform, named by its sha256 hex)
# Env:   IMAGE, TAGS (newline-separated), GITHUB_OUTPUT
set -euo pipefail

dir="$1"

sources=()
for f in "$dir"/*; do
  [ -f "$f" ] || continue
  sources+=("$IMAGE@sha256:$(basename "$f")")
done
if [ "${#sources[@]}" -eq 0 ]; then
  echo "::error::No per-platform digests in $dir"
  exit 1
fi

tag_args=()
while IFS= read -r tag; do
  [ -n "$tag" ] && tag_args+=(-t "$tag")
done <<< "$TAGS"
if [ "${#tag_args[@]}" -eq 0 ]; then
  echo "::error::No tags to apply"
  exit 1
fi

docker buildx imagetools create "${tag_args[@]}" "${sources[@]}"

digest="$(docker buildx imagetools inspect "${tag_args[1]}" --format '{{json .Manifest}}' | jq -r .digest)"
echo "digest=$digest" | tee -a "$GITHUB_OUTPUT"
