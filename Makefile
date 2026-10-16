APP        := devops-intern-task
VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT     ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
IMAGE      := $(APP):$(VERSION)

BUILD_ARGS := --build-arg VERSION=$(VERSION) \
              --build-arg COMMIT=$(COMMIT) \
              --build-arg BUILD_DATE=$(BUILD_DATE)

export VERSION COMMIT BUILD_DATE
export DOCKER_BUILDKIT=1

.DEFAULT_GOAL := help
.PHONY: help run test build docker-build docker-run up down logs health size scan clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

run: ## Run the app locally (needs Go installed)
	go run .

test: ## Run vet + unit tests inside Docker (test stage)
	docker build --target test $(BUILD_ARGS) .

build: ## Build the Go binary locally into ./bin
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT)" -o bin/app .

docker-build: ## Build the production Docker image
	docker build --target final $(BUILD_ARGS) -t $(IMAGE) -t $(APP):latest .

docker-run: docker-build ## Run the image on port 8080 (hardened flags)
	docker run --rm -p 8080:8080 --read-only --cap-drop ALL \
	  --security-opt no-new-privileges:true $(IMAGE)

up: ## Start with docker compose (build + detached)
	docker compose up --build -d

down: ## Stop and remove compose containers
	docker compose down

logs: ## Follow container logs
	docker compose logs -f

health: ## Show container health status
	docker inspect --format='{{.State.Health.Status}}' $(APP)

size: ## Show image size
	docker images $(APP)

scan: ## Scan image for vulnerabilities (needs trivy)
	trivy image --severity HIGH,CRITICAL $(IMAGE)

clean: ## Remove local binary and images
	rm -rf bin
	-docker rmi $(IMAGE) $(APP):latest
