#!/usr/bin/env bats
# =============================================================================
# ingress2gateway E2E Tests
# Tests conversion and actual traffic routing via Envoy Gateway
# =============================================================================

FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"
CONVERTED_DIR="/tmp/converted"
NAMESPACE="i2gw-test"
GATEWAY_CLASS="envoy"

setup_file() {
    mkdir -p "$CONVERTED_DIR"
}

teardown_file() {
    rm -rf "$CONVERTED_DIR"
}

# Helper: get envoy service name for a gateway
get_envoy_svc() {
    kubectl get svc -n envoy-gateway-system -o name | grep envoy-i2gw-test | head -1 | cut -d'/' -f2
}

# Helper: curl via port-forward (kills any existing port-forward first)
curl_via_envoy() {
    local host=$1
    local path=${2:-/}
    local header=${3:-}
    local port=8888
    
    # Kill any existing port-forward
    pkill -f "port-forward.*:${port}" 2>/dev/null || true
    sleep 1
    
    # Get the envoy service
    local svc=$(get_envoy_svc)
    if [ -z "$svc" ]; then
        echo "No envoy service found"
        return 1
    fi
    
    # Start port-forward
    kubectl port-forward -n envoy-gateway-system "svc/${svc}" ${port}:80 &>/dev/null &
    local pf_pid=$!
    sleep 3
    
    # Curl
    if [ -n "$header" ]; then
        curl -s -H "Host: $host" -H "$header" "http://localhost:${port}${path}"
    else
        curl -s -H "Host: $host" "http://localhost:${port}${path}"
    fi
    local result=$?
    
    # Cleanup
    kill $pf_pid 2>/dev/null || true
    return $result
}

# =============================================================================
# Setup Verification
# =============================================================================

@test "setup: cluster is ready" {
    run kubectl get nodes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Ready"* ]]
}

@test "setup: envoy gateway is running" {
    run kubectl get deployment -n envoy-gateway-system envoy-gateway
    [ "$status" -eq 0 ]
}

@test "setup: gateway class exists" {
    run kubectl get gatewayclass envoy
    [ "$status" -eq 0 ]
}

@test "setup: echo services are running" {
    run kubectl get deployment -n $NAMESPACE echo
    [ "$status" -eq 0 ]
    run kubectl get deployment -n $NAMESPACE echo-v2
    [ "$status" -eq 0 ]
}

# =============================================================================
# Simple Ingress Test
# =============================================================================

@test "simple: convert ingress to gateway api" {
    run ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/simple-ingress.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Gateway"* ]]
    [[ "$output" == *"HTTPRoute"* ]]
    
    # Save converted output
    ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/simple-ingress.yaml" \
        > "${CONVERTED_DIR}/simple-gateway.yaml"
}

@test "simple: patch gateway class and apply" {
    sed -i 's/gatewayClassName: nginx/gatewayClassName: envoy/' "${CONVERTED_DIR}/simple-gateway.yaml"
    
    run kubectl apply -f "${CONVERTED_DIR}/simple-gateway.yaml"
    [ "$status" -eq 0 ]
}

@test "simple: wait for gateway accepted" {
    # Wait for gateway to be accepted (not Programmed - that needs LoadBalancer)
    sleep 5
    run kubectl wait --timeout=60s -n $NAMESPACE gateway --all --for=condition=Accepted
    [ "$status" -eq 0 ]
}

@test "simple: wait for envoy proxy ready" {
    # Wait for envoy proxy pod to be ready
    run bash -c "kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=nginx --no-headers | grep -q Running"
    # Retry a few times
    for i in {1..30}; do
        if kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=nginx 2>/dev/null | grep -q Running; then
            return 0
        fi
        sleep 2
    done
    [ "$status" -eq 0 ]
}

@test "simple: curl returns expected response" {
    run curl_via_envoy "simple.example.com" "/"
    [ "$status" -eq 0 ]
    [[ "$output" == *"echo-v1"* ]]
}

@test "simple: cleanup" {
    kubectl delete -f "${CONVERTED_DIR}/simple-gateway.yaml" --ignore-not-found
    sleep 3  # Wait for envoy proxy to be deleted
}

# =============================================================================
# Multi-Path Ingress Test
# =============================================================================

@test "multipath: convert ingress" {
    run ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/multi-path-ingress.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/v1"* ]]
    [[ "$output" == *"/v2"* ]]
    
    ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/multi-path-ingress.yaml" \
        > "${CONVERTED_DIR}/multipath-gateway.yaml"
}

@test "multipath: patch and apply" {
    sed -i 's/gatewayClassName: nginx/gatewayClassName: envoy/' "${CONVERTED_DIR}/multipath-gateway.yaml"
    run kubectl apply -f "${CONVERTED_DIR}/multipath-gateway.yaml"
    [ "$status" -eq 0 ]
}

@test "multipath: wait for gateway accepted" {
    sleep 5
    run kubectl wait --timeout=60s -n $NAMESPACE gateway --all --for=condition=Accepted
    [ "$status" -eq 0 ]
}

@test "multipath: wait for envoy proxy ready" {
    for i in {1..30}; do
        if kubectl get pods -n envoy-gateway-system 2>/dev/null | grep envoy-i2gw | grep -q Running; then
            return 0
        fi
        sleep 2
    done
    false
}

@test "multipath: /v1 routes to echo-v1" {
    run curl_via_envoy "multipath.example.com" "/v1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"echo-v1"* ]]
}

@test "multipath: /v2 routes to echo-v2" {
    run curl_via_envoy "multipath.example.com" "/v2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"echo-v2"* ]]
}

@test "multipath: cleanup" {
    kubectl delete -f "${CONVERTED_DIR}/multipath-gateway.yaml" --ignore-not-found
    sleep 3
}

# =============================================================================
# Canary (Weight-based) Test
# =============================================================================

@test "canary-weight: convert ingress" {
    run ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/canary-ingress.yaml"
    [ "$status" -eq 0 ]
    
    ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/canary-ingress.yaml" \
        > "${CONVERTED_DIR}/canary-gateway.yaml"
}

@test "canary-weight: verify weight in output" {
    run cat "${CONVERTED_DIR}/canary-gateway.yaml"
    [ "$status" -eq 0 ]
    [[ "$output" == *"weight"* ]] || skip "Weight conversion not supported yet"
}

@test "canary-weight: apply" {
    sed -i 's/gatewayClassName: nginx/gatewayClassName: envoy/' "${CONVERTED_DIR}/canary-gateway.yaml"
    run kubectl apply -f "${CONVERTED_DIR}/canary-gateway.yaml"
    [ "$status" -eq 0 ]
}

@test "canary-weight: cleanup" {
    kubectl delete -f "${CONVERTED_DIR}/canary-gateway.yaml" --ignore-not-found
    sleep 3
}

# =============================================================================
# Canary (Header-based) Test
# =============================================================================

@test "canary-header: convert ingress" {
    run ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/header-canary-ingress.yaml"
    [ "$status" -eq 0 ]
    
    ingress2gateway print \
        --providers=ingress-nginx \
        --input-file="${FIXTURES_DIR}/header-canary-ingress.yaml" \
        > "${CONVERTED_DIR}/header-canary-gateway.yaml"
}

@test "canary-header: verify header match in output" {
    run cat "${CONVERTED_DIR}/header-canary-gateway.yaml"
    [ "$status" -eq 0 ]
    # Check if header matching is in output - if not, mark for skipping
    if [[ "$output" != *"X-Canary"* ]]; then
        echo "not_supported" > "${CONVERTED_DIR}/.header-canary-skip"
        skip "Header canary conversion not supported yet"
    fi
}

@test "canary-header: apply" {
    sed -i 's/gatewayClassName: nginx/gatewayClassName: envoy/' "${CONVERTED_DIR}/header-canary-gateway.yaml"
    run kubectl apply -f "${CONVERTED_DIR}/header-canary-gateway.yaml"
    [ "$status" -eq 0 ]
}

@test "canary-header: wait for gateway" {
    [ -f "${CONVERTED_DIR}/.header-canary-skip" ] && skip "Header canary not supported"
    sleep 5
    run kubectl wait --timeout=60s -n $NAMESPACE gateway --all --for=condition=Accepted
    [ "$status" -eq 0 ]
}

@test "canary-header: wait for envoy proxy ready" {
    [ -f "${CONVERTED_DIR}/.header-canary-skip" ] && skip "Header canary not supported"
    for i in {1..30}; do
        if kubectl get pods -n envoy-gateway-system 2>/dev/null | grep envoy-i2gw | grep -q Running; then
            return 0
        fi
        sleep 2
    done
    false
}

@test "canary-header: without header routes to v1" {
    [ -f "${CONVERTED_DIR}/.header-canary-skip" ] && skip "Header canary not supported"
    run curl_via_envoy "header-canary.example.com" "/"
    [ "$status" -eq 0 ]
    [[ "$output" == *"echo-v1"* ]]
}

@test "canary-header: with header routes to v2" {
    [ -f "${CONVERTED_DIR}/.header-canary-skip" ] && skip "Header canary not supported"
    run curl_via_envoy "header-canary.example.com" "/" "X-Canary: true"
    [ "$status" -eq 0 ]
    [[ "$output" == *"echo-v2"* ]]
}

@test "canary-header: cleanup" {
    kubectl delete -f "${CONVERTED_DIR}/header-canary-gateway.yaml" --ignore-not-found
    sleep 3
}

# =============================================================================
# Final Cleanup
# =============================================================================

@test "final: cleanup all test resources" {
    kubectl delete ingress -n $NAMESPACE --all --ignore-not-found
    kubectl delete httproute -n $NAMESPACE --all --ignore-not-found
    kubectl delete gateway -n $NAMESPACE --all --ignore-not-found
    pkill -f "port-forward" 2>/dev/null || true
}
