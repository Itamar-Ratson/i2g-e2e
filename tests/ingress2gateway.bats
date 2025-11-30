#!/usr/bin/env bats

# =============================================================================
# ingress2gateway E2E Tests
# =============================================================================

setup() {
    # Ensure we can talk to the cluster
    kubectl cluster-info &>/dev/null || skip "No cluster available"
}

# -----------------------------------------------------------------------------
# CLI Tests
# -----------------------------------------------------------------------------

@test "CLI: help command works" {
    run ingress2gateway --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"print"* ]]
}

@test "CLI: version command works" {
    run ingress2gateway version
    [ "$status" -eq 0 ]
}

@test "CLI: print --help shows providers" {
    run ingress2gateway print --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--providers"* ]]
}

# -----------------------------------------------------------------------------
# Cluster Tests
# -----------------------------------------------------------------------------

@test "Cluster: nodes are ready" {
    run kubectl get nodes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready"* ]]
}

@test "Cluster: can create namespace" {
    run kubectl create namespace i2gw-test --dry-run=client -o yaml
    [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Conversion Tests (from file)
# -----------------------------------------------------------------------------

@test "Convert: simple ingress to gateway" {
    # Create temp ingress file
    cat > /tmp/test-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-service
            port:
              number: 80
EOF

    run ingress2gateway print --input-file=/tmp/test-ingress.yaml
    [ "$status" -eq 0 ]
    [[ "$output" == *"Gateway"* ]]
    [[ "$output" == *"HTTPRoute"* ]]
}

@test "Convert: ingress with TLS" {
    cat > /tmp/tls-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: default
spec:
  tls:
  - hosts:
    - secure.example.com
    secretName: tls-secret
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 443
EOF

    run ingress2gateway print --input-file=/tmp/tls-ingress.yaml
    [ "$status" -eq 0 ]
    [[ "$output" == *"Gateway"* ]]
    [[ "$output" == *"HTTPS"* ]] || [[ "$output" == *"tls"* ]]
}

@test "Convert: multiple hosts" {
    cat > /tmp/multi-host.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host
spec:
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
EOF

    run ingress2gateway print --input-file=/tmp/multi-host.yaml
    [ "$status" -eq 0 ]
    [[ "$output" == *"app1.example.com"* ]]
    [[ "$output" == *"app2.example.com"* ]]
}

@test "Convert: multiple paths" {
    cat > /tmp/multi-path.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
EOF

    run ingress2gateway print --input-file=/tmp/multi-path.yaml
    [ "$status" -eq 0 ]
    [[ "$output" == *"/api"* ]]
    [[ "$output" == *"/web"* ]]
}

# -----------------------------------------------------------------------------
# Provider-specific Tests
# -----------------------------------------------------------------------------

@test "Convert: ingress-nginx provider" {
    cat > /tmp/nginx-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: nginx.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-svc
            port:
              number: 80
EOF

    run ingress2gateway print --providers=ingress-nginx --input-file=/tmp/nginx-ingress.yaml
    [ "$status" -eq 0 ]
}

# -----------------------------------------------------------------------------
# Edge Cases
# -----------------------------------------------------------------------------

@test "Convert: empty file fails gracefully" {
    echo "" > /tmp/empty.yaml
    run ingress2gateway print --input-file=/tmp/empty.yaml
    # Should not crash
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "Convert: non-existent file fails" {
    run ingress2gateway print --input-file=/tmp/does-not-exist.yaml
    [ "$status" -ne 0 ]
}

@test "Convert: pathType Exact" {
    cat > /tmp/exact-path.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: exact-path
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /exact
        pathType: Exact
        backend:
          service:
            name: exact-svc
            port:
              number: 80
EOF

    run ingress2gateway print --input-file=/tmp/exact-path.yaml
    [ "$status" -eq 0 ]
    [[ "$output" == *"Exact"* ]]
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

teardown() {
    rm -f /tmp/test-ingress.yaml /tmp/tls-ingress.yaml /tmp/multi-host.yaml \
          /tmp/multi-path.yaml /tmp/nginx-ingress.yaml /tmp/empty.yaml \
          /tmp/exact-path.yaml 2>/dev/null || true
}
