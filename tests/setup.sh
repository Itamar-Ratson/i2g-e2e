#!/bin/bash
# Setup script - run once after cluster is ready
set -e

MANIFESTS_DIR="/opt/manifests"

echo "=== Waiting for cluster to be ready ==="
until kubectl cluster-info &>/dev/null; do
  echo "Waiting for cluster..."
  sleep 2
done
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "=== Installing Gateway API CRDs ==="
kubectl apply -f "${MANIFESTS_DIR}/gateway-api.yaml"

echo "=== Installing Envoy Gateway ==="
kubectl apply --server-side --force-conflicts -f "${MANIFESTS_DIR}/envoy-gateway.yaml"

echo "=== Waiting for Envoy Gateway ==="
kubectl wait --timeout=120s -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

echo "=== Creating test namespace ==="
kubectl create namespace i2gw-test --dry-run=client -o yaml | kubectl apply -f -

echo "=== Deploying echo servers ==="
kubectl apply -n i2gw-test -f "${MANIFESTS_DIR}/echo-services.yaml"

echo "=== Waiting for echo deployments ==="
kubectl wait --timeout=60s -n i2gw-test deployment/echo --for=condition=Available
kubectl wait --timeout=60s -n i2gw-test deployment/echo-v2 --for=condition=Available

echo "=== Creating GatewayClass ==="
kubectl apply -f "${MANIFESTS_DIR}/gateway-class.yaml"

echo "=== Setup complete ==="
