#!/usr/bin/env bash
# Resolve image name, Dockerfile, build target and platform for the docker job.
#
# Usage: resolve-docker-config.sh <framework> <default-target>
# Env:   APP_DIR, REGISTRY, IMAGE_NAME, DOCKERFILE, PUSH, RUNNER_ARCH, GITHUB_REPOSITORY, GITHUB_OUTPUT
set -euo pipefail

framework="$1"
target="$2"

image="${IMAGE_NAME:-$REGISTRY/$GITHUB_REPOSITORY}"
image="$(printf '%s' "$image" | tr '[:upper:]' '[:lower:]')"

if [ -n "${DOCKERFILE:-}" ]; then
  dockerfile="$APP_DIR/$DOCKERFILE"
  target=""  # a project Dockerfile has its own stages; build its last one
else
  dockerfile=".ptl/docker/Dockerfile.$framework"
fi
if [ ! -f "$dockerfile" ]; then
  echo "::error::Dockerfile not found: $dockerfile"
  exit 1
fi

case "${RUNNER_ARCH:-X64}" in
  ARM64) local_platform=linux/arm64 ;;
  *)     local_platform=linux/amd64 ;;
esac

# One BuildKit cache per image, so several images in one repo don't evict each other.
cache_scope="$(printf '%s' "${image#*/}" | tr -c 'a-z0-9._-' '-')"

{
  echo "image=$image"
  echo "dockerfile=$dockerfile"
  echo "target=$target"
  echo "local-platform=$local_platform"
  echo "scan-tag=ptl-scan/$cache_scope:$GITHUB_RUN_ID"
  echo "cache-scope=$cache_scope"
  echo "push=$PUSH"
} | tee -a "$GITHUB_OUTPUT"
