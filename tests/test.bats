#!/usr/bin/env bats
# Quick smoke tests - run these first

@test "smoke: ingress2gateway binary exists" {
    command -v ingress2gateway
}

@test "smoke: kubectl binary exists" {
    command -v kubectl
}

@test "smoke: cluster is reachable" {
    kubectl cluster-info
}

@test "smoke: ingress2gateway help works" {
    ingress2gateway --help
}
