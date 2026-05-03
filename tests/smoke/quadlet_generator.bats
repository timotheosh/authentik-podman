#!/usr/bin/env bats
# Smoke test for the Quadlet generator dry-run.
# Validates: Requirement 1.3
#
# This test invokes the Podman Quadlet generator in dry-run mode and verifies
# that all unit files parse without errors and produce the expected service names.

# ---------------------------------------------------------------------------
# Quadlet generator dry-run
# ---------------------------------------------------------------------------

@test "Quadlet generator runs successfully in dry-run mode" {
    run /usr/lib/systemd/system-generators/podman-system-generator -user -dryrun
    [ "$status" -eq 0 ]
}

@test "Quadlet generator produces authentik-database-volume.service" {
    output=$(/usr/lib/systemd/system-generators/podman-system-generator -user -dryrun 2>&1)
    echo "$output" | grep -qF 'authentik-database-volume.service'
}

@test "Quadlet generator produces authentik-network.service" {
    output=$(/usr/lib/systemd/system-generators/podman-system-generator -user -dryrun 2>&1)
    echo "$output" | grep -qF 'authentik-network.service'
}

@test "Quadlet generator produces postgresql.service" {
    output=$(/usr/lib/systemd/system-generators/podman-system-generator -user -dryrun 2>&1)
    echo "$output" | grep -qF 'postgresql.service'
}

@test "Quadlet generator produces authentik-server.service" {
    output=$(/usr/lib/systemd/system-generators/podman-system-generator -user -dryrun 2>&1)
    echo "$output" | grep -qF 'authentik-server.service'
}

@test "Quadlet generator produces authentik-worker.service" {
    output=$(/usr/lib/systemd/system-generators/podman-system-generator -user -dryrun 2>&1)
    echo "$output" | grep -qF 'authentik-worker.service'
}
