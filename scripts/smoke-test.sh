#!/usr/bin/env bash
# Start the image and wait for its HEALTHCHECK to report healthy.
# Env: IMAGE, SMOKE_TEST_ENV (KEY=VALUE lines), SMOKE_TEST_TIMEOUT (seconds, default 60)
set -euo pipefail

name="smoke-$$"
timeout="${SMOKE_TEST_TIMEOUT:-60}"
env_file="$(mktemp)"
printf '%s\n' "${SMOKE_TEST_ENV:-}" > "$env_file"

if [ "$(docker image inspect --format '{{if .Config.Healthcheck}}yes{{end}}' "$IMAGE")" != yes ]; then
  echo "::error::Image has no HEALTHCHECK"
  exit 1
fi

# shellcheck disable=SC2329 # invoked by trap
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -f "$env_file"; }
trap cleanup EXIT

# Probe every 2s instead of the image's 30s interval; everything else comes from the image.
docker run -d --name "$name" --env-file "$env_file" --health-interval=2s "$IMAGE" >/dev/null

for _ in $(seq 1 "$timeout"); do
  status="$(docker inspect --format '{{.State.Status}} {{.State.Health.Status}}' "$name")"
  case "$status" in
    "running healthy")
      echo "Container is healthy"
      echo "- **Smoke test:** healthy" >> "$GITHUB_STEP_SUMMARY"
      exit 0 ;;
    running*) sleep 1 ;;
    *) break ;;
  esac
done

echo "::error::Container did not become healthy within ${timeout}s (state: $status)"
docker inspect --format '{{json .State.Health}}' "$name" || true
echo "---- container logs ----"
docker logs "$name" 2>&1 | tail -n 100
exit 1
