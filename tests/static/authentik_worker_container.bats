#!/usr/bin/env bats
# Static validation tests for the authentik-worker.container Quadlet unit file.
# Validates: Requirements 3.4, 10.1, 10.3
#
# These tests check that the Authentik worker container unit contains the
# correct directives without requiring a live Podman or systemd instance.

QUADLET_DIR="${HOME}/.config/containers/systemd"

# ---------------------------------------------------------------------------
# File existence
# ---------------------------------------------------------------------------

@test "authentik-worker.container exists" {
    [ -f "${QUADLET_DIR}/authentik-worker.container" ]
}

# ---------------------------------------------------------------------------
# Image (Requirement 10.1)
# ---------------------------------------------------------------------------

@test "authentik-worker.container has Image=ghcr.io/goauthentik/server:2026.2" {
    grep -qF 'Image=ghcr.io/goauthentik/server:2026.2' "${QUADLET_DIR}/authentik-worker.container"
}

# ---------------------------------------------------------------------------
# Process command
# ---------------------------------------------------------------------------

@test "authentik-worker.container has Exec=worker" {
    grep -qF 'Exec=worker' "${QUADLET_DIR}/authentik-worker.container"
}

# ---------------------------------------------------------------------------
# Dependency ordering (Requirement 3.4)
# ---------------------------------------------------------------------------

@test "authentik-worker.container has After=postgresql-healthy.service" {
    grep -qF 'After=postgresql-healthy.service' "${QUADLET_DIR}/authentik-worker.container"
}

@test "authentik-worker.container has Requires=postgresql-healthy.service" {
    grep -qF 'Requires=postgresql-healthy.service' "${QUADLET_DIR}/authentik-worker.container"
}

# ---------------------------------------------------------------------------
# No auto-update (Requirement 10.3)
# ---------------------------------------------------------------------------

@test "authentik-worker.container does not contain AutoUpdate=registry" {
    run grep -F 'AutoUpdate=registry' "${QUADLET_DIR}/authentik-worker.container"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# No Docker socket mount (Requirement 10.1 — rootless, no socket needed)
# ---------------------------------------------------------------------------

@test "authentik-worker.container does not mount the Docker socket" {
    run grep -F '/var/run/docker.sock' "${QUADLET_DIR}/authentik-worker.container"
    [ "$status" -ne 0 ]
}
