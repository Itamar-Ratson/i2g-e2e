# ingress2gateway E2E Test Environment

KinD-based environment for testing ingress2gateway contributions.

## Quick Start

```bash
# Build and start (first run takes ~3-5 min for cluster + setup)
docker compose up -d --build

# Read logs (wait for "Ready!" message then exit with CTRL+C)
docker compose logs -f

# Enter the container
docker compose exec i2gw-test bash

# Run tests
bats /workspace/tests/e2e.bats
```

## What's Included

- **KinD cluster**: `i2gw-test` (auto-created on startup)
- **Gateway Controller**: Envoy Gateway (auto-installed)
- **Tools**: kubectl, kind, go, bats, git, make, curl
- **Source**: `/workspace/ingress2gateway` (cloned and built)

Note: First container start takes ~2-3 min (cluster creation + Envoy Gateway install). Subsequent `exec` sessions are instant.

## Directory Structure

```
.
├── docker-compose.yaml
├── Dockerfile
├── entrypoint.sh
├── README.md
├── manifests/
│   ├── kind-config.yaml       # KinD cluster configuration
│   ├── echo-services.yaml     # Echo server deployments
│   └── gateway-class.yaml     # Envoy GatewayClass
└── tests/
    ├── e2e.bats               # Full e2e tests with traffic verification
    ├── test.bats              # Smoke tests
    ├── setup.sh               # Manual setup (auto-runs on first start)
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

1. Add fixture to `tests/fixtures/`
2. Add test case to `tests/e2e.bats`
3. Pattern: convert → apply → curl → verify

## Cleanup

```bash
docker compose down -v
```
