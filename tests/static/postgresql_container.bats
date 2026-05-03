#!/usr/bin/env bats
# Static validation tests for the postgresql.container Quadlet unit file.
# Validates: Requirements 3.5, 5.1, 6.4, 9.1, 9.3
#
# These tests check that the PostgreSQL container unit contains the correct
# directives without requiring a live Podman or systemd instance.

QUADLET_DIR="${HOME}/.config/containers/systemd"

# ---------------------------------------------------------------------------
# File existence
# ---------------------------------------------------------------------------

@test "postgresql.container exists" {
    [ -f "${QUADLET_DIR}/postgresql.container" ]
}

# ---------------------------------------------------------------------------
# Image and container identity
# ---------------------------------------------------------------------------

@test "postgresql.container has Image=docker.io/library/postgres:16-alpine" {
    grep -qF 'Image=docker.io/library/postgres:16-alpine' "${QUADLET_DIR}/postgresql.container"
}

@test "postgresql.container has ContainerName=postgresql" {
    grep -qF 'ContainerName=postgresql' "${QUADLET_DIR}/postgresql.container"
}

# ---------------------------------------------------------------------------
# Healthcheck configuration (Requirement 3.5)
# ---------------------------------------------------------------------------

@test "postgresql.container has HealthCmd=pg_isready -d \$POSTGRES_DB -U \$POSTGRES_USER" {
    grep -qF 'HealthCmd=pg_isready -d $POSTGRES_DB -U $POSTGRES_USER' "${QUADLET_DIR}/postgresql.container"
}

@test "postgresql.container has HealthInterval=30s" {
    grep -qF 'HealthInterval=30s' "${QUADLET_DIR}/postgresql.container"
}

@test "postgresql.container has HealthTimeout=5s" {
    grep -qF 'HealthTimeout=5s' "${QUADLET_DIR}/postgresql.container"
}

@test "postgresql.container has HealthStartPeriod=20s" {
    grep -qF 'HealthStartPeriod=20s' "${QUADLET_DIR}/postgresql.container"
}

@test "postgresql.container has HealthRetries=5" {
    grep -qF 'HealthRetries=5' "${QUADLET_DIR}/postgresql.container"
}

# ---------------------------------------------------------------------------
# Volume configuration (Requirement 5.1)
# ---------------------------------------------------------------------------

@test "postgresql.container has Volume=authentik-database.volume:/var/lib/postgresql/data" {
    grep -qF 'Volume=authentik-database.volume:/var/lib/postgresql/data' "${QUADLET_DIR}/postgresql.container"
}

# ---------------------------------------------------------------------------
# Auto-update (Requirements 9.1, 9.3)
# ---------------------------------------------------------------------------

@test "postgresql.container has AutoUpdate=registry" {
    grep -qF 'AutoUpdate=registry' "${QUADLET_DIR}/postgresql.container"
}

# ---------------------------------------------------------------------------
# No host port exposure (Requirement 6.4)
# ---------------------------------------------------------------------------

@test "postgresql.container does not contain a PublishPort= directive" {
    run grep -F 'PublishPort=' "${QUADLET_DIR}/postgresql.container"
    [ "$status" -ne 0 ]
}
