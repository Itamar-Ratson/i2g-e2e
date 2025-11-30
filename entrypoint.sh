#!/bin/bash
set -e

# 1. Start the Docker Daemon in the background
echo "🐳 Starting Docker Daemon..."
dockerd-entrypoint.sh >/dev/null 2>&1 &

# 2. Wait for Docker to be ready
echo "⏳ Waiting for Docker to start..."
timeout 30s bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'
echo "✅ Docker is up!"

# 3. Create the KinD cluster automatically
# We check if it exists first to avoid errors on restarts if you persist data
if ! kind get clusters | grep -q "i2gw-test"; then
  echo "📦 Creating KinD cluster 'i2gw-test'..."
  kind create cluster --name i2gw-test
else
  echo "✅ KinD cluster 'i2gw-test' already exists."
fi

# 4. Export Kubeconfig so kubectl works immediately
export KUBECONFIG="$(kind get kubeconfig-path --name="i2gw-test")"

# 5. Execute the command passed to docker run (defaulting to bash)
exec "$@"
