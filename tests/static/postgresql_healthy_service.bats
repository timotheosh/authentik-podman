#!/usr/bin/env bats
# Static validation tests for the postgresql-healthy.service health-gate unit.
# Validates: Requirements 3.3, 3.6
#
# These tests check that the oneshot health-gate service contains the correct
# directives without requiring a live Podman or systemd instance.

QUADLET_DIR="${HOME}/.config/containers/systemd"

# ---------------------------------------------------------------------------
# File existence
# ---------------------------------------------------------------------------

@test "postgresql-healthy.service exists" {
    [ -f "${QUADLET_DIR}/postgresql-healthy.service" ]
}

# ---------------------------------------------------------------------------
# Service type (Requirement 3.3)
# ---------------------------------------------------------------------------

@test "postgresql-healthy.service has Type=oneshot" {
    grep -qF 'Type=oneshot' "${QUADLET_DIR}/postgresql-healthy.service"
}

@test "postgresql-healthy.service has RemainAfterExit=yes" {
    grep -qF 'RemainAfterExit=yes' "${QUADLET_DIR}/postgresql-healthy.service"
}

# ---------------------------------------------------------------------------
# Timeout configuration (Requirement 3.6)
# ---------------------------------------------------------------------------

@test "postgresql-healthy.service has TimeoutStartSec=180" {
    grep -qF 'TimeoutStartSec=180' "${QUADLET_DIR}/postgresql-healthy.service"
}

# ---------------------------------------------------------------------------
# Dependency ordering (Requirements 3.3, 3.6)
# ---------------------------------------------------------------------------

@test "postgresql-healthy.service has After=postgresql.service" {
    grep -qF 'After=postgresql.service' "${QUADLET_DIR}/postgresql-healthy.service"
}

@test "postgresql-healthy.service has Requires=postgresql.service" {
    grep -qF 'Requires=postgresql.service' "${QUADLET_DIR}/postgresql-healthy.service"
}
