#!/usr/bin/env bats
# Static validation tests for Quadlet volume and network unit files.
# Validates: Requirements 1.2, 6.1
#
# These tests check file existence and correct section headers without
# requiring a live Podman or systemd instance.

QUADLET_DIR="${HOME}/.config/containers/systemd"

# ---------------------------------------------------------------------------
# authentik-database.volume
# ---------------------------------------------------------------------------

@test "authentik-database.volume exists" {
    [ -f "${QUADLET_DIR}/authentik-database.volume" ]
}

@test "authentik-database.volume contains a [Volume] section" {
    grep -qF '[Volume]' "${QUADLET_DIR}/authentik-database.volume"
}

# ---------------------------------------------------------------------------
# authentik.network
# ---------------------------------------------------------------------------

@test "authentik.network exists" {
    [ -f "${QUADLET_DIR}/authentik.network" ]
}

@test "authentik.network contains a [Network] section" {
    grep -qF '[Network]' "${QUADLET_DIR}/authentik.network"
}
