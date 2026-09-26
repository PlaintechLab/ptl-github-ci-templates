# syntax=docker/dockerfile:1
#
# Go backend: static binary, cross-compiled on the build platform.
#
# Targets:
#   runtime-alpine      (default) Alpine with CA certs and tzdata. Target < 50 MB.
#   runtime-distroless  gcr.io/distroless/static, no shell. Target < 20 MB.
#
# Both runtimes probe health with a tiny static Go binary (no wget/curl needed).
#
# Build args:
#   GO_VERSION, ALPINE_VERSION  base image versions
#   MAIN_PACKAGE                package or file to build (default ./cmd/main.go)
#   VERSION                     stamped into main.version via -ldflags
#   HEALTHCHECK_PATH            path probed by HEALTHCHECK (default /health)
#   PORT                        port the app listens on (default 8000)

ARG GO_VERSION=1.25
ARG ALPINE_VERSION=3

# ---- builder ------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS builder
WORKDIR /src
ENV CGO_ENABLED=0 GOFLAGS=-trimpath
COPY go.mod go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY <<'EOF' /healthcheck/main.go
// healthcheck exits 0 when http://127.0.0.1:$PORT$HEALTHCHECK_PATH answers 2xx/3xx.
package main

import (
	"net/http"
	"os"
	"time"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}
	path := os.Getenv("HEALTHCHECK_PATH")
	if path == "" {
		path = "/health"
	}
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + path)
	if err != nil {
		os.Exit(1)
	}
	resp.Body.Close()
	if resp.StatusCode >= 400 {
		os.Exit(1)
	}
}
EOF

ARG TARGETOS TARGETARCH
ARG MAIN_PACKAGE=./cmd/main.go
ARG VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,target=.,rw \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-s -w -X main.version=${VERSION}" -o /out/app "${MAIN_PACKAGE}" \
 && GOOS=$TARGETOS GOARCH=$TARGETARCH go build -C /healthcheck -ldflags="-s -w" -o /out/healthcheck main.go

# ---- runtime-distroless ----------------------------------------------------------
FROM gcr.io/distroless/static-debian13:nonroot AS runtime-distroless
ARG HEALTHCHECK_PATH=/health
ARG PORT=8000
ENV GO_ENV=production \
    PORT=${PORT} \
    HEALTHCHECK_PATH=${HEALTHCHECK_PATH}
COPY --from=builder /out/app /app
COPY --from=builder /out/healthcheck /healthcheck
USER 1001:1001
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD ["/healthcheck"]
ENTRYPOINT ["/app"]

# ---- runtime-alpine (default: last stage) --------------------------------------------
FROM alpine:${ALPINE_VERSION} AS runtime-alpine
ARG HEALTHCHECK_PATH=/health
ARG PORT=8000
RUN apk upgrade --no-cache \
 && apk add --no-cache ca-certificates tzdata \
 && addgroup -S -g 1001 app \
 && adduser -S -D -H -u 1001 -G app app
ENV GO_ENV=production \
    PORT=${PORT} \
    HEALTHCHECK_PATH=${HEALTHCHECK_PATH}
COPY --from=builder /out/app /usr/local/bin/app
COPY --from=builder /out/healthcheck /usr/local/bin/healthcheck
USER 1001:1001
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]
ENTRYPOINT ["/usr/local/bin/app"]
