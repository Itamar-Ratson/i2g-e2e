# ingress2gateway E2E Test Environment

KinD-based environment for testing ingress2gateway contributions.

## Quick Start

```bash
# Build and start (first time takes ~2-3 min)
docker compose up -d --build

# Enter the container
docker compose exec i2gw-test bash

# Run tests
bats /workspace/tests/
```

## What's Included

- **KinD cluster**: `i2gw-test` (auto-created on startup)
- **Tools**: kubectl, kind, go, bats, git, make
- **Source**: `/workspace/ingress2gateway` (cloned and built)

## Development Workflow

```bash
# Inside container - rebuild after changes
cd /workspace/ingress2gateway
go build -o /usr/local/bin/ingress2gateway .

# Run your tests
bats /workspace/tests/

# Or run project's own tests
make test
```

## Cleanup

```bash
docker compose down -v
```
