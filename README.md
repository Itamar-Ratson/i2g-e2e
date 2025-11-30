# ingress2gateway E2E Test Environment

KinD-based environment for testing ingress2gateway contributions.

## Quick Start

```bash
# Build and start (first time takes ~3-5 min)
docker compose up -d --build

# Enter the container
docker compose exec i2gw-test bash

# One-time setup: install Envoy Gateway + test services
bash /workspace/tests/setup.sh

# Run smoke tests
bats /workspace/tests/test.bats

# Run full e2e tests
bats /workspace/tests/e2e.bats
```

## What's Included

- **KinD cluster**: `i2gw-test` (auto-created on startup)
- **Gateway Controller**: Envoy Gateway (installed via setup.sh)
- **Tools**: kubectl, kind, go, bats, git, make, curl
- **Source**: `/workspace/ingress2gateway` (cloned and built)

## Test Structure

```
tests/
├── test.bats              # Smoke tests (run first)
├── e2e.bats               # Full e2e tests with traffic verification
├── setup.sh               # Installs Envoy Gateway + test services
└── fixtures/
    ├── simple-ingress.yaml
    ├── multi-path-ingress.yaml
    ├── canary-ingress.yaml        # Weight-based canary
    └── header-canary-ingress.yaml # Header-based canary
```

## Test Flow

1. Convert Ingress → Gateway API using `ingress2gateway print`
2. Apply converted resources to cluster
3. Curl endpoints to verify routing works

## Development Workflow

```bash
# Inside container - rebuild after changes
cd /workspace/ingress2gateway
go build -o /usr/local/bin/ingress2gateway .

# Run specific test
bats /workspace/tests/e2e.bats --filter "simple"

# Run all tests
bats /workspace/tests/
```

## Adding Tests

1. Add fixture to `fixtures/`
2. Add test case to `e2e.bats`
3. Pattern: convert → apply → curl → verify

## Cleanup

```bash
docker compose down -v
```
