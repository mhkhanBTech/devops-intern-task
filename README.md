# DevOps Intern Task - Step 1

A minimal Go web app with a production-ready Docker setup.

`GET /` returns:
```json
{"message": "Hello from DevOps Intern Task!", "status": "running"}
```

## Project structure
```
.
├── main.go              # web app (single endpoint "/")
├── main_test.go         # unit tests
├── go.mod
├── Dockerfile           # multi-stage: deps -> test -> build -> final
├── docker-compose.yml   # runs the app on port 8080
├── Makefile             # shortcuts for build / test / run
├── .dockerignore
└── .gitignore
```

## Quick start
Requirements: Docker (with Compose). `make` is optional.

```bash
make up                  # or: docker compose up --build -d
curl http://localhost:8080/
make health              # container health status
make down                # stop
```

Run `make help` to see all commands.

## Docker best practices applied
**Layering**
- `go.mod` is copied and dependencies are downloaded before the source code, so code changes do not re-download modules
- BuildKit cache mounts speed up rebuilds
- `.dockerignore` keeps the build context small

**Small image**
- Multi-stage build: the Go toolchain stays in the build stage
- Static binary (`CGO_ENABLED=0`, `-s -w`, `-trimpath`) copied into a distroless image (no shell, no package manager)
- Check the size with `make size`

**Container hygiene**
- Runs as non-root user (UID 65532)
- Read-only filesystem, all capabilities dropped, `no-new-privileges`
- `HEALTHCHECK` without curl (binary has a `-healthcheck` flag)
- Graceful shutdown and HTTP server timeouts
- Memory, CPU and PID limits and log rotation in compose
- Pinned base image versions, OCI labels (version, commit, build date)
- Optional vulnerability scan: `make scan` (Trivy)

## Git workflow
Commits follow [Conventional Commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `docs:`, `test:`, `chore:`.
