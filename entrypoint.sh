#!/bin/bash
set -e

# Start Docker daemon in background
dockerd-entrypoint.sh >/dev/null 2>&1 &

# Wait for Docker (max 60s)
echo "Starting Docker..."
timeout 60s bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'
echo "Docker ready."

CLUSTER_NAME="i2gw-test"
SETUP_DONE="/tmp/.setup-complete"
MANIFESTS_DIR="/opt/manifests"

# Pre-pull images while doing other things (runs in background)
pull_images() {
  docker pull hashicorp/http-echo:0.2.3 &>/dev/null
  docker pull docker.io/envoyproxy/gateway:v1.2.0 &>/dev/null
  docker pull docker.io/envoyproxy/envoy:distroless-v1.32.3 &>/dev/null
}

if ! kind get clusters 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "Pre-pulling images..."
  pull_images &
  PULL_PID=$!

  echo "Creating KinD cluster..."
  kind create cluster --name "${CLUSTER_NAME}" --config="${MANIFESTS_DIR}/kind-config.yaml"

  # Wait for image pulls to complete
  wait $PULL_PID 2>/dev/null || true

  # Load pre-pulled images into KinD (much faster than pulling inside)
  echo "Loading images into cluster..."
  kind load docker-image --name "${CLUSTER_NAME}" \
    hashicorp/http-echo:0.2.3 \
    docker.io/envoyproxy/gateway:v1.2.0 \
    docker.io/envoyproxy/envoy:distroless-v1.32.3 &>/dev/null || true

  rm -f "$SETUP_DONE"
fi

# Always export kubeconfig
kind export kubeconfig --name "${CLUSTER_NAME}"

# Run setup if not already done
if [ ! -f "$SETUP_DONE" ]; then
  echo "Installing Gateway API + Envoy Gateway..."
  kubectl apply -f "${MANIFESTS_DIR}/gateway-api.yaml" &>/dev/null
  kubectl apply --server-side --force-conflicts -f "${MANIFESTS_DIR}/envoy-gateway.yaml" &>/dev/null

  echo "Waiting for Envoy Gateway..."
  kubectl wait --timeout=90s -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

  echo "Creating test namespace + echo servers..."
  kubectl create namespace i2gw-test --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
  kubectl apply -n i2gw-test -f "${MANIFESTS_DIR}/echo-services.yaml" &>/dev/null

  kubectl apply -f "${MANIFESTS_DIR}/gateway-class.yaml"

  echo "Waiting for deployments..."
  kubectl wait --timeout=60s -n i2gw-test deployment/echo deployment/echo-v2 --for=condition=Available

  touch "$SETUP_DONE"
  echo "=== Ready! ==="
fi

# Start interactive shell or run provided command
if [ $# -eq 0 ]; then
  exec /bin/bash
else
  exec "$@"
fi
