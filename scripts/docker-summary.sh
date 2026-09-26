#!/usr/bin/env bash
# Write the image name, digest and tags to the job summary.
# Env: IMAGE, DIGEST, TAGS, GITHUB_STEP_SUMMARY
set -euo pipefail

{
  echo "- **Image:** \`${IMAGE:-n/a}\`"
  echo "- **Digest:** \`${DIGEST:-not pushed}\`"
  echo
  if [ -n "${DIGEST:-}" ] && [ -n "${TAGS:-}" ]; then
    echo "**Tags**"
    echo
    # shellcheck disable=SC2016 # literal backticks for Markdown
    printf '%s\n' "$TAGS" | sed '/^$/d; s/.*/- `&`/'
  fi
} >> "$GITHUB_STEP_SUMMARY"
