# Implementation Plan: podman-quadlet-authentik

## Overview

Create the six Quadlet/systemd unit files that replace the existing Docker Compose stack with rootless Podman services managed by systemd. The implementation is purely declarative: write the files, validate them statically, then verify the generator and runtime behaviour with smoke and integration tests.

## Tasks

- [x] 1. Create output directory and shared environment file template
  - Create `~/.config/containers/systemd/` if it does not already exist
  - Write a `.env.example` file in the same directory documenting every required key (`PG_DB`, `PG_USER`, `PG_PASS`, `AUTHENTIK_SECRET_KEY`) with placeholder values and inline comments
  - Do NOT write a `.env` file with real secrets; the operator copies `.env.example` to `.env` and fills in values
  - _Requirements: 4.1, 4.2, 4.3, 4.7_

- [x] 2. Write the volume and network Quadlet units
  - [x] 2.1 Create `authentik-database.volume`
    - Write `~/.config/containers/systemd/authentik-database.volume` with a `[Volume]` section (no extra options needed; default local driver)
    - _Requirements: 1.2, 5.7_
  - [x] 2.2 Create `authentik.network`
    - Write `~/.config/containers/systemd/authentik.network` with a `[Network]` section (default bridge driver with DNS)
    - _Requirements: 6.1_
  - [x] 2.3 Write static validation tests for volume and network units
    - Assert `authentik-database.volume` exists and contains a `[Volume]` section
    - Assert `authentik.network` exists and contains a `[Network]` section
    - _Requirements: 1.2, 6.1_

- [x] 3. Write the PostgreSQL container unit
  - [x] 3.1 Create `postgresql.container`
    - Write `~/.config/containers/systemd/postgresql.container` with:
      - `[Container]` section: `Image=docker.io/library/postgres:16-alpine`, `ContainerName=postgresql`, `Network=authentik.network`, `Volume=authentik-database.volume:/var/lib/postgresql/data`, `EnvironmentFile=` (path to `.env`), `Environment=POSTGRES_DB=${PG_DB}`, `Environment=POSTGRES_USER=${PG_USER}`, `Environment=POSTGRES_PASSWORD=${PG_PASS}`, `HealthCmd=pg_isready -d $POSTGRES_DB -U $POSTGRES_USER`, `HealthInterval=30s`, `HealthTimeout=5s`, `HealthStartPeriod=20s`, `HealthRetries=5`, `AutoUpdate=registry`
      - `[Service]` section: `Restart=always`
      - No `PublishPort=` directive
      - No `User=root` directive
    - _Requirements: 1.1, 2.2, 3.5, 4.1, 4.4, 5.1, 6.1, 6.4, 8.1, 9.1, 9.3_
  - [ ]* 3.2 Write property test — no container runs as root (Property 1)
    - **Property 1: No container runs as root**
    - Iterate over `{postgresql.container, authentik-server.container, authentik-worker.container}`; assert `User=root` is absent in each
    - **Validates: Requirements 2.2, 2.3, 2.4**
  - [ ]* 3.3 Write property test — every container loads an environment file (Property 2)
    - **Property 2: Every container loads an environment file**
    - Iterate over the same three container files; assert `EnvironmentFile=` is present in each
    - **Validates: Requirements 4.1, 4.2, 4.3**
  - [ ]* 3.4 Write property test — auto-update policy (Property 3)
    - **Property 3: PostgreSQL has AutoUpdate=registry; Authentik containers do not**
    - Assert `postgresql.container` contains `AutoUpdate=registry`; assert `authentik-server.container` and `authentik-worker.container` do NOT contain `AutoUpdate=registry`
    - **Validates: Requirements 9.1, 10.2, 10.3**
  - [ ]* 3.5 Write property test — every container restarts automatically (Property 4)
    - **Property 4: Every container restarts automatically**
    - Iterate over the three container files; assert `Restart=always` is present in the `[Service]` section of each
    - **Validates: Requirements 8.1, 8.2, 8.3**
  - [x] 3.6 Write static validation tests for `postgresql.container`
    - Assert `Image=docker.io/library/postgres:16-alpine`
    - Assert `ContainerName=postgresql`
    - Assert `HealthCmd=pg_isready -d $POSTGRES_DB -U $POSTGRES_USER`
    - Assert `HealthInterval=30s`, `HealthTimeout=5s`, `HealthStartPeriod=20s`, `HealthRetries=5`
    - Assert `Volume=authentik-database.volume:/var/lib/postgresql/data`
    - Assert `AutoUpdate=registry`
    - Assert no `PublishPort=` directive
    - _Requirements: 3.5, 5.1, 6.4, 9.1, 9.3_

- [x] 4. Write the postgresql-healthy.service health-gate unit
  - [x] 4.1 Create `postgresql-healthy.service`
    - Write `~/.config/containers/systemd/postgresql-healthy.service` with:
      - `[Unit]` section: `Description=Wait for PostgreSQL container to be healthy`, `After=postgresql.service`, `Requires=postgresql.service`
      - `[Service]` section: `Type=oneshot`, `RemainAfterExit=yes`, `ExecStart=/bin/sh -c 'until podman healthcheck run postgresql; do sleep 2; done'`, `TimeoutStartSec=180`
    - _Requirements: 3.3, 3.4, 3.6_
  - [x] 4.2 Write static validation tests for `postgresql-healthy.service`
    - Assert `Type=oneshot`
    - Assert `RemainAfterExit=yes`
    - Assert `TimeoutStartSec=180`
    - Assert `After=postgresql.service` and `Requires=postgresql.service`
    - _Requirements: 3.3, 3.6_

- [x] 5. Write the Authentik server container unit
  - [x] 5.1 Create `authentik-server.container`
    - Write `~/.config/containers/systemd/authentik-server.container` with:
      - `[Unit]` section: `After=postgresql-healthy.service`, `Requires=postgresql-healthy.service`
      - `[Container]` section: `Image=ghcr.io/goauthentik/server:2026.2`, `Exec=server`, `Network=authentik.network`, `PublishPort=127.0.0.1:9000:9000`, `Volume=%h/authentik/data:/data`, `Volume=%h/authentik/custom-templates:/templates`, `EnvironmentFile=` (path to `.env`), `Environment=AUTHENTIK_POSTGRESQL__HOST=postgresql`, `Environment=AUTHENTIK_POSTGRESQL__NAME=${PG_DB}`, `Environment=AUTHENTIK_POSTGRESQL__USER=${PG_USER}`, `Environment=AUTHENTIK_POSTGRESQL__PASSWORD=${PG_PASS}`, `Environment=AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}`, `ShmSize=512m`
      - `[Service]` section: `Restart=always`
      - No `AutoUpdate=registry` directive
      - No `User=root` directive
    - _Requirements: 1.1, 2.3, 3.1, 3.3, 4.2, 4.5, 5.2, 5.3, 6.1, 6.2, 6.5, 7.1, 8.2, 10.1, 10.2_
  - [ ]* 5.2 Write property test — Authentik containers have sufficient shared memory (Property 5)
    - **Property 5: Authentik application containers have sufficient shared memory**
    - Iterate over `{authentik-server.container, authentik-worker.container}`; assert `ShmSize=512m` is present in each
    - **Validates: Requirements 7.1, 7.2**
  - [ ]* 5.3 Write property test — Authentik containers declare all required environment variables (Property 6)
    - **Property 6: Authentik application containers declare all required environment variables**
    - Iterate over `{authentik-server.container, authentik-worker.container}`; assert all five variables are declared: `AUTHENTIK_POSTGRESQL__HOST`, `AUTHENTIK_POSTGRESQL__NAME`, `AUTHENTIK_POSTGRESQL__PASSWORD`, `AUTHENTIK_POSTGRESQL__USER`, `AUTHENTIK_SECRET_KEY`
    - **Validates: Requirements 4.5, 4.6**
  - [x] 5.4 Write static validation tests for `authentik-server.container`
    - Assert `Image=ghcr.io/goauthentik/server:2026.2`
    - Assert `Exec=server`
    - Assert `PublishPort=127.0.0.1:9000:9000` (literal, no variable substitution)
    - Assert `After=postgresql-healthy.service` and `Requires=postgresql-healthy.service`
    - Assert no `AutoUpdate=registry`
    - _Requirements: 3.3, 6.5, 10.1, 10.2_

- [x] 6. Write the Authentik worker container unit
  - [x] 6.1 Create `authentik-worker.container`
    - Write `~/.config/containers/systemd/authentik-worker.container` with:
      - `[Unit]` section: `After=postgresql-healthy.service`, `Requires=postgresql-healthy.service`
      - `[Container]` section: `Image=ghcr.io/goauthentik/server:2026.2`, `Exec=worker`, `Network=authentik.network`, `Volume=%h/authentik/data:/data`, `Volume=%h/authentik/certs:/certs`, `Volume=%h/authentik/custom-templates:/templates`, `EnvironmentFile=` (path to `.env`), `Environment=AUTHENTIK_POSTGRESQL__HOST=postgresql`, `Environment=AUTHENTIK_POSTGRESQL__NAME=${PG_DB}`, `Environment=AUTHENTIK_POSTGRESQL__USER=${PG_USER}`, `Environment=AUTHENTIK_POSTGRESQL__PASSWORD=${PG_PASS}`, `Environment=AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY}`, `ShmSize=512m`
      - `[Service]` section: `Restart=always`
      - No `AutoUpdate=registry` directive
      - No `User=root` directive
      - No Docker socket mount
    - _Requirements: 1.1, 2.4, 3.2, 3.4, 4.3, 4.6, 5.4, 5.5, 5.6, 6.1, 6.3, 7.2, 8.3, 10.1, 10.3_
  - [ ]* 6.2 Write property test — worker declares all required bind mounts (Property 7)
    - **Property 7: Worker container declares all required bind mounts**
    - For `authentik-worker.container`, assert `Volume=` directives for all three paths are present: `%h/authentik/data:/data`, `%h/authentik/certs:/certs`, `%h/authentik/custom-templates:/templates`
    - **Validates: Requirements 5.4, 5.5, 5.6**
  - [x] 6.3 Write static validation tests for `authentik-worker.container`
    - Assert `Image=ghcr.io/goauthentik/server:2026.2`
    - Assert `Exec=worker`
    - Assert `After=postgresql-healthy.service` and `Requires=postgresql-healthy.service`
    - Assert no `AutoUpdate=registry`
    - Assert no Docker socket `Volume=` entry
    - _Requirements: 3.4, 10.1, 10.3_

- [x] 7. Checkpoint — all static tests pass
  - Ensure all static file validation tests and property tests pass, ask the user if questions arise.

- [x] 8. Smoke test — Quadlet generator dry-run
  - [x] 8.1 Run the Quadlet generator in dry-run mode
    - Execute `/usr/lib/systemd/system-generators/podman-system-generator --user --dry-run` against the output directory
    - Verify all six files parse without errors and the generator produces the expected `.service` unit names
    - _Requirements: 1.3_
  - [x] 8.2 Write an automated smoke test script
    - Write a test that invokes the generator with `--dry-run` and asserts a zero exit code and the presence of expected service names in the output
    - _Requirements: 1.3_

- [ ] 9. Integration tests
  - [ ]* 9.1 Write integration test — dependency chain enforcement
    - Start only `postgresql.service`; assert `authentik-server.service` and `authentik-worker.service` remain inactive until `postgresql-healthy.service` exits successfully
    - _Requirements: 3.3, 3.4, 3.6_
  - [ ]* 9.2 Write integration test — missing env file causes descriptive failure
    - Remove `.env`, attempt `systemctl --user start authentik-server.service`, assert the unit fails with a descriptive activation error (not a silent no-op)
    - _Requirements: 4.7_
  - [ ]* 9.3 Write integration test — container restart on failure
    - Kill the PostgreSQL container process; assert systemd restarts it automatically
    - _Requirements: 8.4_
  - [ ]* 9.4 Write integration test — auto-update dry-run reports only PostgreSQL
    - Run `podman auto-update --dry-run`; assert `postgresql` appears as a candidate; assert `authentik-server` and `authentik-worker` do NOT appear
    - _Requirements: 9.1, 10.2, 10.3_

- [x] 10. Final checkpoint — all tests pass
  - Ensure all static, smoke, and integration tests pass. Confirm the six files are present in `~/.config/containers/systemd/` and that `systemctl --user daemon-reload` completes without errors. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests (tasks 3.2–3.5, 5.2–5.3, 6.2) iterate over sets of files and assert invariants; a simple shell loop or bats parameterised test achieves this without a dedicated PBT library
- The `EnvironmentFile=` path must NOT be prefixed with `-`; a missing `.env` must cause a hard failure (Requirement 4.7)
- After all files are in place, enable the auto-update timer once with `systemctl --user enable --now podman-auto-update.timer`
- Authentik updates are intentionally manual: `podman pull ghcr.io/goauthentik/server:2026.2` → review changelog → `systemctl --user restart authentik-server.service authentik-worker.service`
