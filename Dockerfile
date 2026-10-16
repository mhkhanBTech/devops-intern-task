# syntax=docker/dockerfile:1.7

# =====================================================================
# Production multi-stage Dockerfile (Go)
#   Stages:  deps -> test -> build -> final
#   Build:   make docker-build      (passes VERSION / COMMIT / BUILD_DATE)
# =====================================================================

ARG GO_VERSION=1.22
ARG ALPINE_VERSION=3.20

# ---------- Stage 1: dependencies (cached layer) ----------
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS deps
WORKDIR /src
COPY go.mod go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# ---------- Stage 2: tests (run with: make test) ----------
FROM deps AS test
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go vet ./... && go test ./...

# ---------- Stage 3: build static binary ----------
FROM deps AS build
ARG VERSION=dev
ARG COMMIT=none
ARG TARGETOS=linux
ARG TARGETARCH
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath \
      -ldflags="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT}" \
      -o /out/app .

# ---------- Stage 4: minimal, non-root runtime ----------
FROM gcr.io/distroless/static-debian12:nonroot AS final

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="devops-intern-task" \
      org.opencontainers.image.description="Minimal Go web app for DevOps intern task" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY --from=build /out/app /app

# distroless "nonroot" = UID/GID 65532 (never root)
USER 65532:65532
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app", "-healthcheck"]

ENTRYPOINT ["/app"]
