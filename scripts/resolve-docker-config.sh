#!/usr/bin/env bash
# Resolve image name, Dockerfile, build target and platform for the docker job.
#
# Usage: resolve-docker-config.sh <framework> <default-target>
# Env:   APP_DIR, REGISTRY, IMAGE_NAME, DOCKERFILE, PUSH, RUNNER_ARCH, GITHUB_REPOSITORY, GITHUB_OUTPUT
#        WORKSPACE_ROOT, WORKING_DIRECTORY (optional: app inside a Bun workspace)
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

# Build context and app path. Standalone project: context is the app itself.
# Bun workspace: context is the workspace root, and APP_DIR (the Dockerfile build arg)
# is the app's path inside it.
normalize() {
  local p="${1#./}"
  p="${p%/}"
  printf '%s' "${p:-.}"
}
if [ -z "${WORKSPACE_ROOT:-}" ]; then
  context="$APP_DIR"
  app_path=.
else
  root="$(normalize "$WORKSPACE_ROOT")"
  wd="$(normalize "$WORKING_DIRECTORY")"
  case "/$root/ /$wd/" in
    */../*) echo "::error::workspace-root and working-directory must not contain '..'"; exit 1 ;;
  esac
  if [ "$root" = . ]; then
    app_path="$wd"
  elif [ "$wd" = "$root" ]; then
    app_path=.
  elif [ "${wd#"$root"/}" != "$wd" ]; then
    app_path="${wd#"$root"/}"
  else
    echo "::error::working-directory ($wd) must be inside workspace-root ($root)"
    exit 1
  fi
  if [ "$root" = . ]; then context=src; else context="src/$root"; fi
  if [ ! -f "$context/bun.lock" ] && [ ! -f "$context/bun.lockb" ]; then
    echo "::error::No bun.lock or bun.lockb in workspace-root ($root)"
    exit 1
  fi
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
  echo "context=$context"
  echo "app-path=$app_path"
  echo "target=$target"
  echo "local-platform=$local_platform"
  echo "scan-tag=ptl-scan/$cache_scope:$GITHUB_RUN_ID"
  echo "cache-scope=$cache_scope"
  echo "push=$PUSH"
} | tee -a "$GITHUB_OUTPUT"
