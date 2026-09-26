#!/usr/bin/env bash
# Report the image size and fail when it exceeds MAX_MB (0 disables the check).
# Env: IMAGE, MAX_MB, GITHUB_STEP_SUMMARY
set -euo pipefail

bytes="$(docker image inspect --format '{{.Size}}' "$IMAGE")"
mb=$(( (bytes + 1048575) / 1048576 ))
echo "Image size: ${mb} MB"
echo "- **Image size:** ${mb} MB (limit: ${MAX_MB:-0} MB, 0 = none)" >> "$GITHUB_STEP_SUMMARY"

if [ "${MAX_MB:-0}" -gt 0 ] && [ "$mb" -gt "$MAX_MB" ]; then
  echo "::error::Image is ${mb} MB, over the ${MAX_MB} MB limit (max-image-size-mb)"
  exit 1
fi
