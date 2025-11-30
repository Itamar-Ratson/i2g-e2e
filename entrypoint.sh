#!/bin/bash
set -e

# Start Docker daemon in background
dockerd-entrypoint.sh >/dev/null 2>&1 &

# Wait for Docker (max 60s)
echo "Starting Docker..."
timeout 60s bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'
echo "Docker ready."

# Create KinD cluster if not exists
CLUSTER_NAME="i2gw-test"
if ! kind get clusters 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "Creating KinD cluster..."
  kind create cluster --name "${CLUSTER_NAME}" --wait 60s
  echo "Cluster ready."
else
  echo "Cluster already exists."
fi

# Start interactive shell or run provided command
if [ $# -eq 0 ]; then
  exec /bin/bash
else
  exec "$@"
fi
