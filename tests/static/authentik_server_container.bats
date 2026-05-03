#!/usr/bin/env bats
# Static validation tests for the authentik-server.container Quadlet unit file.
# Validates: Requirements 3.3, 6.5, 10.1, 10.2
#
# These tests check that the Authentik server container unit contains the
# correct directives without requiring a live Podman or systemd instance.

QUADLET_DIR="${HOME}/.config/containers/systemd"

# ---------------------------------------------------------------------------
# File existence
# ---------------------------------------------------------------------------

@test "authentik-server.container exists" {
    [ -f "${QUADLET_DIR}/authentik-server.container" ]
}

# ---------------------------------------------------------------------------
# Image (Requirement 10.1)
# ---------------------------------------------------------------------------

@test "authentik-server.container has Image=ghcr.io/goauthentik/server:2026.2" {
    grep -qF 'Image=ghcr.io/goauthentik/server:2026.2' "${QUADLET_DIR}/authentik-server.container"
}

# ---------------------------------------------------------------------------
# Process command
# ---------------------------------------------------------------------------

@test "authentik-server.container has Exec=server" {
    grep -qF 'Exec=server' "${QUADLET_DIR}/authentik-server.container"
}

# ---------------------------------------------------------------------------
# Port binding — literal, no variable substitution (Requirement 6.5)
# ---------------------------------------------------------------------------

@test "authentik-server.container has PublishPort=127.0.0.1:9000:9000" {
    grep -qF 'PublishPort=127.0.0.1:9000:9000' "${QUADLET_DIR}/authentik-server.container"
}

# ---------------------------------------------------------------------------
# Dependency ordering (Requirement 3.3)
# ---------------------------------------------------------------------------

@test "authentik-server.container has After=postgresql-healthy.service" {
    grep -qF 'After=postgresql-healthy.service' "${QUADLET_DIR}/authentik-server.container"
}

@test "authentik-server.container has Requires=postgresql-healthy.service" {
    grep -qF 'Requires=postgresql-healthy.service' "${QUADLET_DIR}/authentik-server.container"
}

# ---------------------------------------------------------------------------
# No auto-update (Requirement 10.2)
# ---------------------------------------------------------------------------

@test "authentik-server.container does not contain AutoUpdate=registry" {
    run grep -F 'AutoUpdate=registry' "${QUADLET_DIR}/authentik-server.container"
    [ "$status" -ne 0 ]
}
