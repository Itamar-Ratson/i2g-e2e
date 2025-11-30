#!/usr/bin/env bats

@test "Verify ingress2gateway help command works" {
  run ingress2gateway --help
  [ "$status" -eq 0 ]
}

@test "Verify we can talk to the KinD cluster" {
  run kubectl get nodes
  [ "$status" -eq 0 ]
}
