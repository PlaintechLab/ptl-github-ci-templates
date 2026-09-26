# Generation Prompts for ptl-github-templates

Use these prompts to generate similar configurations for other frameworks. Customize based on your specific needs.

> **Note (2026-09):** the templates generated from these prompts deviate where the prompts are out of date or
> contradict themselves. Node 20/21 and Go 1.21/1.22 are EOL, so CI defaults to Node 22/24 and Go `go.mod` + `stable`.
> `oven/bun:latest-alpine` is not a real tag (`oven/bun:1-alpine` is). Elysia runs on Bun by default, because it only
> runs on Node with `@elysiajs/node`. OIDC is used for cosign signing, and ghcr.io uses `GITHUB_TOKEN`.
> Update the version numbers below before reusing a prompt.

---

## 📋 Generic Template Prompt

```markdown
Create a production-ready CI/CD template for [FRAMEWORK] following PlaintechLab standards:

**Requirements:**
1. GitHub Actions Reusable Workflow (.github/workflows/build-[framework].yml)
   - Lint & test jobs (matrix strategy with [VERSIONS])
   - Docker build & push with multi-stage
   - Security scanning (Trivy)
   - Artifact management (5 day retention)
   - Health checks

2. Multi-stage Dockerfile (docker/Dockerfile.[framework])
   - Builder stage: Bun-based build
   - Runtime stage: Alpine-based, non-root user, health check
   - Optimized for production (minimal size, security hardening)

3. Framework Configuration (templates/[framework].yaml)
   - Build commands and outputs
   - Docker settings (ports, environment variables)
   - GitHub Actions matrix & caching settings
   - Performance targets
   - Security requirements

4. Usage Example
   - Show how to call this workflow from a project

**Standards to follow:**
- Use Bun as package manager where possible
- Multi-architecture Docker builds (linux/amd64, linux/arm64)
- Non-root user (uid: 1001)
- Health checks required
- Secrets via GitHub OIDC
- Caching for dependencies
- Matrix builds for multiple Node versions
```

---

## 🔹 Prompt for ElysiaJS Backend

```markdown
Create a CI/CD template for ElysiaJS backend using Bun:

**Framework Details:**
- Runtime: Node.js 20+
- Package Manager: Bun
- Build Output: dist/
- Entry Point: dist/index.js or dist/index.mjs
- Port: 3000 (default, configurable)
- Key Commands:
  - Development: bun run dev
  - Build: bun run build
  - Test: bun run test
  - Lint: bun run lint

**Docker Configuration:**
- Builder: oven/bun:latest-alpine
- Runtime: node:20-alpine
- Health Check: HTTP GET /health endpoint
- Environment Variables:
  - NODE_ENV=production
  - BUN_ENV=production
  - PORT=3000

**GitHub Actions:**
- Matrix: Node versions 20, 21
- Cache: Bun lockfile
- Artifacts: dist/ directory
- Security: Trivy + Node dependencies audit

**Output Files:**
1. .github/workflows/build-elysia.yml
2. docker/Dockerfile.elysia
3. templates/elysia.yaml
```

---

## 🔷 Prompt for Next.js Frontend

```markdown
Create a CI/CD template for Next.js frontend using Bun:

**Framework Details:**
- Runtime: Node.js 20+
- Package Manager: Bun
- Build Output: .next/
- Static Files: public/
- Port: 3000 (dev), configurable in production
- Key Commands:
  - Development: bun run dev
  - Build: bun run build
  - Start: bun run start
  - Lint: bun run lint
  - Test: bun run test

**Docker Configuration:**
- Builder: oven/bun:latest-alpine
- Runtime: node:20-alpine or distroless/nodejs20-nonroot
- Health Check: HTTP GET / endpoint
- Environment Variables:
  - NODE_ENV=production
  - NEXT_TELEMETRY_DISABLED=1
- Optimization: Enable static exports if SPA

**GitHub Actions:**
- Matrix: Node versions 20, 21
- Cache: Bun lockfile + Next.js cache
- Artifacts: .next/, public/
- Security: Dependency audit

**Performance Targets:**
- Build time: < 5 minutes
- Image size: < 400MB
- Bundle size tracking

**Output Files:**
1. .github/workflows/build-nextjs.yml
2. docker/Dockerfile.nextjs
3. templates/nextjs.yaml
```

---

## 🟦 Prompt for Go Backend

```markdown
Create a CI/CD template for Go backend:

**Framework Details:**
- Runtime: Go 1.21+
- Build Output: Binary (configurable name)
- Port: 8000 (default, configurable)
- Package Manager: Go modules
- Key Commands:
  - Build: go build -o ./bin/app ./cmd/main.go
  - Test: go test ./...
  - Lint: golangci-lint run
  - Format: gofmt -s -w .

**Docker Configuration:**
- Builder: golang:1.21-alpine
- Runtime: alpine:latest or distroless/base
- Health Check: HTTP GET /health endpoint
- Environment Variables:
  - GO_ENV=production
  - PORT=8000
- Optimization: Minimal runtime (distroless)

**GitHub Actions:**
- Matrix: Go versions 1.21, 1.22
- Cache: Go modules cache
- Artifacts: Binary, SBOM
- Security: gosec + dependency checks

**Performance Targets:**
- Build time: < 3 minutes
- Image size: < 50MB (Alpine) or < 20MB (distroless)
- Binary size: < 30MB

**Output Files:**
1. .github/workflows/build-go.yml
2. docker/Dockerfile.go
3. templates/go.yaml
```

---

## 🟩 Prompt for Creating Composite Actions

```markdown
Create a reusable GitHub Actions composite action for [PURPOSE]:

**Requirements:**
1. Name: [ACTION_NAME]
2. Description: Clear, concise description
3. Inputs:
   - List all configurable inputs
   - Set sensible defaults
   - Include descriptions
4. Outputs:
   - What should this action export?
5. Implementation:
   - Use shell scripts or JavaScript
   - Add error handling
   - Include logging/echo statements for debugging

**Standard Pattern:**
- Input validation
- Main task execution
- Output generation
- Status reporting

**Example: For any framework setup action**
- Inputs: version, enable-caching, production-only
- Outputs: installation-path, cache-hit, duration
- Steps: install runtime, cache setup, dependency install, verification
```

---

## 📝 Prompt for Creating Framework Templates

```markdown
Create a framework template configuration file (YAML) for [FRAMEWORK]:

**Include Sections:**
1. **Framework Info**
   - name, version, runtime, package_manager

2. **Build Commands**
   - dev, build, test, lint, preview (if applicable)

3. **Build Configuration**
   - output_dir, static_dir, environment, optimizations

4. **Docker Configuration**
   - base images, healthcheck, ports, environment variables, security

5. **GitHub Actions Settings**
   - node versions, matrix strategy, caching, job configs

6. **Environment Variables**
   - per-stage (development, staging, production)

7. **Registry Configuration**
   - image naming, tagging strategy

8. **Artifact Management**
   - retention, inclusions, exclusions

9. **Performance Targets**
   - build time, image size, startup time

10. **Security Settings**
    - scanning, SBOM, non-root user, health checks

**Output:** templates/[framework].yaml (YAML format, well-commented)
```

---

## 🎯 Quick Reference: Framework Checklist

When creating a new framework template, ensure you have:

- [ ] Reusable workflow (.github/workflows/build-[framework].yml)
- [ ] Multi-stage Dockerfile (docker/Dockerfile.[framework])
- [ ] Framework template config (templates/[framework].yaml)
- [ ] Composite action (if needed) (.github/actions/setup-[framework]/)
- [ ] Example usage in README
- [ ] Security scanning enabled
- [ ] Health check configured
- [ ] Non-root user in runtime stage
- [ ] Caching strategy defined
- [ ] Matrix builds for multiple versions
- [ ] Artifact retention policy
- [ ] Performance targets set

---

## 💡 Pro Tips

1. **Testing New Templates**
   - Create a test project in PlaintechLab (test-[framework])
   - Use workflow to verify all steps work
   - Check final image size and build time
   - Run security scans and verify results

2. **Reusing Patterns**
   - Copy similar framework template and modify
   - Keep naming conventions consistent
   - Share composite actions across frameworks

3. **Version Management**
   - Tag releases in ptl-github-templates
   - Pin major version in projects
   - Document breaking changes

4. **Monitoring**
   - Track build times over commits
   - Monitor image sizes
   - Check security scan trends
   - Alert on failures

---

## 📞 Getting Help

For questions or issues:
1. Check existing templates in ptl-github-templates
2. Review GitHub Actions documentation
3. Test in a test project before promoting
4. Iterate based on real-world usage
