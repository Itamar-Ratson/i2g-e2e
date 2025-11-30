#!/bin/bash
# Setup script - run once after cluster is ready
set -e

echo "=== Waiting for cluster to be ready ==="
until kubectl cluster-info &>/dev/null; do
  echo "Waiting for cluster..."
  sleep 2
done
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "=== Installing Gateway API CRDs ==="
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

echo "=== Installing Envoy Gateway ==="
kubectl apply --server-side --force-conflicts -f https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml

echo "=== Waiting for Envoy Gateway ==="
kubectl wait --timeout=120s -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

echo "=== Creating test namespace ==="
kubectl create namespace i2gw-test --dry-run=client -o yaml | kubectl apply -f -

echo "=== Deploying echo server ==="
kubectl apply -n i2gw-test -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: echo-svc
spec:
  ports:
  - port: 80
    targetPort: 5678
  selector:
    app: echo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:0.2.3
        args: ["-text=echo-v1"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-v2-svc
spec:
  ports:
  - port: 80
    targetPort: 5678
  selector:
    app: echo-v2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-v2
  template:
    metadata:
      labels:
        app: echo-v2
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:0.2.3
        args: ["-text=echo-v2"]
        ports:
        - containerPort: 5678
EOF

echo "=== Waiting for echo deployments ==="
kubectl wait --timeout=60s -n i2gw-test deployment/echo --for=condition=Available
kubectl wait --timeout=60s -n i2gw-test deployment/echo-v2 --for=condition=Available

echo "=== Creating GatewayClass ==="
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF

echo "=== Setup complete ==="
