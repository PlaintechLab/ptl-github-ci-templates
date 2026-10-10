#!/usr/bin/env bash
# Turn the comma-separated platforms input into the build matrix: one leg per platform,
# each on a runner of that architecture, so nothing is built under QEMU emulation.
# Platforms without a native runner fall back to RUNS_ON with QEMU.
#
# Env: PLATFORMS, RUNS_ON, ARM_RUNS_ON (empty: build arm64 on RUNS_ON with QEMU), GITHUB_OUTPUT
set -euo pipefail

legs=()
IFS=',' read -ra requested <<< "${PLATFORMS:-}"
for platform in ${requested[@]+"${requested[@]}"}; do
  platform="$(printf '%s' "$platform" | tr -d '[:space:]')"
  [ -n "$platform" ] || continue
  case "$platform" in
    linux/amd64) runner="$RUNS_ON"; qemu=false ;;
    linux/arm64) runner="${ARM_RUNS_ON:-$RUNS_ON}"; qemu="$([ -n "${ARM_RUNS_ON:-}" ] && echo false || echo true)" ;;
    *)           runner="$RUNS_ON"; qemu=true ;;
  esac
  arch="$(printf '%s' "${platform#*/}" | tr '/' '-')"
  legs+=("$(jq -cn --arg platform "$platform" --arg arch "$arch" --arg runner "$runner" --argjson qemu "$qemu" \
    '{platform: $platform, arch: $arch, runner: $runner, qemu: $qemu}')")
done

if [ "${#legs[@]}" -eq 0 ]; then
  echo "::error::platforms is empty"
  exit 1
fi

echo "matrix=$(printf '%s\n' "${legs[@]}" | jq -cs '{include: .}')" | tee -a "$GITHUB_OUTPUT"
