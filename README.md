# ptl-github-ci-templates

Reusable GitHub Actions workflow + Dockerfile กลางของ PlaintechLab. Project เรียกใช้ workflow เดียวแล้วได้ครบ:
lint → test → dependency audit → build → Docker image (multi-arch) → smoke test health check → Trivy scan → push → cosign sign

| Framework | Workflow | Dockerfile | Config อ้างอิง |
| --- | --- | --- | --- |
| ElysiaJS (Bun) | [build-elysia.yml](.github/workflows/build-elysia.yml) | [Dockerfile.elysia](docker/Dockerfile.elysia) | [elysia.yaml](templates/elysia.yaml) |
| Next.js | [build-nextjs.yml](.github/workflows/build-nextjs.yml) | [Dockerfile.nextjs](docker/Dockerfile.nextjs) | [nextjs.yaml](templates/nextjs.yaml) |
| Nuxt 4 | [build-nuxt4.yml](.github/workflows/build-nuxt4.yml) | [Dockerfile.nuxt4](docker/Dockerfile.nuxt4) | [nuxt4.yaml](templates/nuxt4.yaml) |
| Go | [build-go.yml](.github/workflows/build-go.yml) | [Dockerfile.go](docker/Dockerfile.go) | [go.yaml](templates/go.yaml) |

## โครงสร้าง

```
.github/
  actions/setup-bun/        composite action: Bun (+ Node) + cache + bun install
  workflows/
    build-{elysia,nextjs,nuxt4,go}.yml   reusable workflow (on: workflow_call)
    ci.yml                  lint repo นี้ + รันทุก workflow กับ test/fixtures (ไม่ push)
    release.yml             tag vX.Y.Z → ย้าย tag vX มาชี้ที่ release นั้น
docker/
  Dockerfile.<framework>                multi-stage, non-root (uid 1001), HEALTHCHECK
  Dockerfile.<framework>.dockerignore   BuildKit ใช้แทน .dockerignore ของ project
scripts/                    shell script ที่ docker job ของทุก workflow ใช้ร่วมกัน
templates/<framework>.yaml  เอกสาร config/convention ของแต่ละ framework (workflow ไม่ได้อ่านไฟล์นี้)
test/fixtures/<framework>/  app เล็กที่สุดที่ผ่านทุก step ใช้ทดสอบใน ci.yml
```

Workflow checkout repo นี้เองที่ commit เดียวกับ workflow ที่ถูกเรียก (`job.workflow_repository` + `job.workflow_sha`)
เพื่อใช้ Dockerfile, script และ composite action. ไม่มีปัญหา version ไม่ตรงกัน แต่ **repo นี้ต้องเป็น public**
เพราะ `GITHUB_TOKEN` ของ project อ่าน private repo อื่นไม่ได้

## ใช้งาน

สร้าง `.github/workflows/ci.yml` ใน project. Permission 4 ตัวนี้ต้องให้ครบ ไม่งั้น workflow ไม่เริ่ม
(job ใน reusable workflow ขอ permission เกินที่ caller ให้ไม่ได้):

### ElysiaJS

```yaml
name: CI
on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:

jobs:
  build:
    uses: PlaintechLab/ptl-github-ci-templates/.github/workflows/build-elysia.yml@v1
    permissions:
      contents: read
      packages: write          # push ghcr.io
      id-token: write          # cosign keyless signing
      security-events: write   # Trivy SARIF → Security tab
    with:
      image-name: ghcr.io/plaintechlab/the-fulfillment-api
```

### Next.js

```yaml
jobs:
  build:
    uses: PlaintechLab/ptl-github-ci-templates/.github/workflows/build-nextjs.yml@v1
    permissions: { contents: read, packages: write, id-token: write, security-events: write }
    with:
      image-name: ghcr.io/plaintechlab/the-fulfillment-portal
    secrets:
      build-env: |                               # optional; ดูหัวข้อ build-env
        NEXT_PUBLIC_API_URL=${{ vars.API_URL }}
        NEXT_PUBLIC_SENTRY_DSN=${{ secrets.SENTRY_DSN }}
```

### Nuxt 4

```yaml
jobs:
  build:
    uses: PlaintechLab/ptl-github-ci-templates/.github/workflows/build-nuxt4.yml@v1
    permissions: { contents: read, packages: write, id-token: write, security-events: write }
    with:
      image-name: ghcr.io/plaintechlab/the-fulfillment-admin
      health-path: /health   # ถ้ามี server/routes/health.ts (default คือ /)
```

Config ที่ต่างกันแต่ละ environment ให้ใช้ `runtimeConfig` แล้ว override ตอน runtime ด้วย env `NUXT_*` / `NUXT_PUBLIC_*`
image เดียวจะใช้ได้ทุก environment. `build-env` ใช้เฉพาะค่าที่ต้องรู้ตอน build จริง ๆ (ดู[หัวข้อ build-env](#build-env-ค่าที่ต้องใช้ตอน-build-elysia-nextjs-nuxt))

### Go

```yaml
jobs:
  build:
    uses: PlaintechLab/ptl-github-ci-templates/.github/workflows/build-go.yml@v1
    permissions: { contents: read, packages: write, id-token: write, security-events: write }
    with:
      image-name: ghcr.io/plaintechlab/the-fulfillment-warehouse
      main-package: ./cmd/server
      runtime: distroless
      max-image-size-mb: 20
```

### Monorepo

เรียก workflow หลายครั้ง แต่ละครั้งใส่ `working-directory`, `image-name` และ `artifact-name` ไม่ซ้ำกัน:

```yaml
jobs:
  api:
    uses: PlaintechLab/ptl-github-ci-templates/.github/workflows/build-elysia.yml@v1
    permissions: { contents: read, packages: write, id-token: write, security-events: write }
    with:
      working-directory: apps/api
      image-name: ghcr.io/plaintechlab/the-fulfillment-api
      artifact-name: api-dist
  portal:
    uses: PlaintechLab/ptl-github-ci-templates/.github/workflows/build-nextjs.yml@v1
    permissions: { contents: read, packages: write, id-token: write, security-events: write }
    with:
      working-directory: apps/portal
      image-name: ghcr.io/plaintechlab/the-fulfillment-portal
      artifact-name: portal-build
```

Output ของ workflow: `image`, `digest` (ว่างถ้าไม่ได้ push), `tags` ใช้ต่อใน job deploy ได้ เช่น `needs.build.outputs.digest`

## สิ่งที่ project ต้องมี

**ทุก framework**
- Endpoint health check ที่ตอบ 2xx/3xx: Elysia/Go `GET /health`, Next.js/Nuxt `GET /` (เปลี่ยนด้วย `health-path`)
- App อ่าน port จาก env `PORT` และ listen `0.0.0.0`
- ถ้า app ต้องมี env บางตัวถึงจะ boot ได้ (DB URL ฯลฯ) ใส่ค่า dummy ผ่าน `smoke-test-env`

**ElysiaJS / Next.js / Nuxt 4**
- Commit `bun.lock` (หรือ `bun.lockb`). CI ใช้ `bun install --frozen-lockfile`
- Script `lint`, `test`, `build` ใน package.json (ไม่มี script ไหนก็ส่ง `lint-command: ""` หรือ `test-command: ""`)
- Elysia: `build` ต้องได้ `dist/index.js` (เปลี่ยนด้วย `entry-point`), เช่น `bun build src/index.ts --target bun --outdir dist`
- Next.js: `output: "standalone"` ใน next.config
- Nuxt 4: ใช้ Nitro preset `node-server` (default) ซึ่ง build ได้ `.output/server/index.mjs`.
  ถ้าใช้ `nuxt typecheck` เป็น lint ต้องใช้ TypeScript 5/6 เพราะ vue-tsc ยังใช้กับ TypeScript 7 ไม่ได้

**Go**
- `go.mod` ที่ root ของ `working-directory`, main package ที่ `./cmd/main.go` (เปลี่ยนด้วย `main-package`)
- ผ่าน `gofmt -s`, `go vet`, golangci-lint (ใช้ `.golangci.yml` ของ project ถ้ามี), gosec, govulncheck

## Inputs หลัก

ดูครบทุกตัวพร้อมคำอธิบายที่ `on.workflow_call.inputs` ของแต่ละ workflow

| Input | Default | หมายเหตุ |
| --- | --- | --- |
| `working-directory` | `.` | directory ของ project ใน repo |
| `image-name` | `ghcr.io/<owner>/<repo>` | convention: `ghcr.io/plaintechlab/<product>-<app>` |
| `push` | `true` | ไม่ push บน `pull_request` เสมอ (build + scan อย่างเดียว) |
| `platforms` | `linux/amd64,linux/arm64` | image ที่ scan/smoke test คือ arch ของ runner |
| `port` / `health-path` | 3000, 8000 (Go) / `/health`, `/` (Next.js, Nuxt) | ส่งเข้า Dockerfile เป็น build arg |
| `node-versions` / `go-versions` | `["22","24"]` / `["go.mod","stable"]` | matrix ของ lint & test |
| `runtime` | Elysia `bun`, Go `alpine` | Elysia: `node` (ต้องใช้ `@elysiajs/node`); Go: `distroless` |
| `trivy-severity` | `CRITICAL,HIGH` | fail เมื่อเจอ severity นี้ที่มี fix แล้ว |
| `max-image-size-mb` | Elysia 0 (ปิด), Next.js/Nuxt 400, Go 50 | |
| `dockerfile` | ว่าง = ใช้ของ repo นี้ | path เทียบกับ `working-directory`; ใช้ stage สุดท้ายของไฟล์ |
| `registry` | `ghcr.io` | registry อื่นใส่ secret `registry-username` / `registry-password` |

### `build-env`: ค่าที่ต้องใช้ตอน build (Elysia, Next.js, Nuxt)

เป็น secret ตัวเดียว เนื้อหาเป็น dotenv บรรทัดละ 1 ค่า `KEY=VALUE` ถูก export ตอน build ทั้งใน CI และใน Docker
(ส่งเป็น BuildKit secret จึงไม่อยู่ใน image layer). มีหลายค่าก็ใส่หลายบรรทัด ทำได้ 2 แบบ:

**แบบ 1: เก็บทั้งก้อนใน GitHub secret ตัวเดียว** (เช่นสร้าง secret `NUXT_BUILD_ENV` ใน Settings → Secrets แล้ววางหลายบรรทัด)

```yaml
    secrets:
      build-env: ${{ secrets.NUXT_BUILD_ENV }}
```

**แบบ 2: ประกอบจาก secret/variable หลายตัวใน caller** (แนะนำ เพราะแก้ทีละค่าได้ และค่าที่ไม่ลับเก็บเป็น variable ได้)

```yaml
    secrets:
      build-env: |
        NUXT_PUBLIC_API_BASE=${{ vars.API_BASE_URL }}
        NUXT_PUBLIC_SITE_NAME=PlaintechLab Admin
        SENTRY_AUTH_TOKEN=${{ secrets.SENTRY_AUTH_TOKEN }}
```

กติกาของไฟล์:

- ค่าอ่านตรงตามตัวอักษร ไม่ผ่าน shell: `$`, `&`, `` ` ``, ช่องว่าง, `;` ใช้ได้เลยไม่ต้อง escape
- ถ้าค่าถูกครอบด้วย `"..."` หรือ `'...'` จะตัด quote คู่นอกสุดออก 1 คู่
- บรรทัดว่างและบรรทัดขึ้นต้นด้วย `#` ถูกข้าม, มี `export ` นำหน้าได้
- ค่าหลายบรรทัดใช้ไม่ได้ (เช่น private key แบบ PEM) ให้ encode เป็น base64 ก่อนแล้วค่อย decode ในโค้ด
- ชื่อตัวแปรผิดรูปแบบ (เช่น `BAD-NAME`) ทำให้ build fail ทันที โดย error บอกแค่เลขบรรทัด ไม่แสดงค่า
- เปลี่ยนค่าแล้ว image จะ build ใหม่แน่นอน (workflow ส่ง sha256 ของ `build-env` เป็น build arg เพราะ BuildKit ไม่นับ secret ใน cache key)

ใช้กับค่าที่ต้องฝังตอน build เท่านั้น เช่น `NEXT_PUBLIC_*` ของ Next.js หรือ token สำหรับ upload source map.
Secret ของ runtime ให้ใส่ผ่าน Kubernetes Secret ([ptl-helm-charts](../ptl-helm-charts) `envFromSecrets`) ไม่ใช่ตอน build.
Nuxt ใช้ `runtimeConfig` + env `NUXT_*` ตอน runtime ได้ จึงแทบไม่ต้องใช้ `build-env`

## Security

- Action ทุกตัว pin ด้วย commit SHA (comment บอก version), `persist-credentials: false`, ทุก job ขอ permission น้อยที่สุด
- Image: non-root uid 1001, code เป็นของ root (app แก้ไม่ได้), `tini` เป็น PID 1, `.env*` ไม่เข้า build context
- Trivy scan image ก่อน push, SARIF ขึ้น Security tab (ถ้า repo ไม่ได้เปิด code scanning step upload จะ warning แต่ไม่ fail)
- Image ที่ push มี provenance (`mode=max`) + SBOM attestation และ sign ด้วย cosign keyless ผ่าน GitHub OIDC ตรวจได้ด้วย:

  ```sh
  cosign verify ghcr.io/plaintechlab/<image>@<digest> \
    --certificate-identity-regexp '^https://github.com/PlaintechLab/ptl-github-ci-templates/' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

  Certificate identity เป็นของ reusable workflow ใน repo นี้ ไม่ใช่ของ project
- Dependency: `bun audit` (fail ที่ `audit-level`, default `high`), Go ใช้ gosec + govulncheck

## Versioning

- Project pin major: `@v1`. Release ใหม่: `git tag v1.2.0 && git push origin v1.2.0` แล้ว [release.yml](.github/workflows/release.yml) ย้าย `v1` มาชี้ให้
- Breaking change (ลบ/เปลี่ยนชื่อ input, เปลี่ยน default ที่ทำให้ build เดิม fail, เปลี่ยน path ใน image) ต้องขึ้น major ใหม่
- Update action ที่ pin ไว้: เปลี่ยน SHA + comment version ทุกที่ที่ใช้ (`grep -rn "actions/checkout@" .github`)

## ทดสอบ

[ci.yml](.github/workflows/ci.yml) รันทุก PR: actionlint, hadolint, shellcheck แล้วเรียกทุก workflow กับ `test/fixtures/*` (`push: false`)

ทดสอบ Dockerfile บนเครื่อง:

```sh
docker buildx build --load -f docker/Dockerfile.go --target runtime-alpine -t ptl-test/go test/fixtures/go
IMAGE=ptl-test/go GITHUB_STEP_SUMMARY=/dev/stdout bash scripts/smoke-test.sh
```

## เพิ่ม framework ใหม่

ใช้ prompt ใน [docs/generation-prompts.md](docs/generation-prompts.md) หรือ copy framework ที่ใกล้ที่สุดแล้วแก้. ต้องมีครบ:

- [ ] `.github/workflows/build-<framework>.yml` (ใช้ `scripts/*` สำหรับ docker job)
- [ ] `docker/Dockerfile.<framework>` + `.dockerignore`: multi-stage, uid 1001, HEALTHCHECK
- [ ] `templates/<framework>.yaml`
- [ ] `test/fixtures/<framework>/` + job ใน `ci.yml`
- [ ] ตัวอย่างการใช้ใน README นี้
