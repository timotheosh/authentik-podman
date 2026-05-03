# Requirements Document

## Introduction

This feature replaces an existing Docker Compose setup for the Authentik identity provider stack with rootless Podman Quadlet systemd unit files. The stack consists of three services: a PostgreSQL database, an Authentik server, and an Authentik worker. The goal is to manage these containers as native systemd services under a non-root user account, preserving all runtime behaviour of the original Compose setup while gaining systemd lifecycle management, dependency ordering, and automatic image update support.

## Glossary

- **Quadlet**: A Podman feature that generates systemd unit files from declarative `.container`, `.volume`, and `.network` definition files placed in `~/.config/containers/systemd/`.
- **Rootless Podman**: Running Podman and its containers without root privileges on the host; the systemd units run as a regular user via `systemctl --user`.
- **PostgreSQL_Container**: The systemd-managed container running `docker.io/library/postgres:16-alpine`.
- **Server_Container**: The systemd-managed container running the Authentik server process (`ghcr.io/goauthentik/server:<tag>`).
- **Worker_Container**: The systemd-managed container running the Authentik worker process (`ghcr.io/goauthentik/server:<tag>`).
- **Authentik_Stack**: The collective set of PostgreSQL_Container, Server_Container, and Worker_Container.
- **Quadlet_Unit**: A `.container`, `.volume`, or `.network` file processed by `podman-system-generator` to produce a systemd unit.
- **Auto-Update**: The `podman auto-update` mechanism that pulls a newer image digest for a running container when the image is tagged with `io.containers.autoupdate=registry`.
- **Minor version upgrade**: An image tag update within the same major version series (e.g., `postgres:16.x → 16.y` or `2026.2.x → 2026.2.y`), as opposed to a major version bump (e.g., `16 → 17`).
- **Env_File**: The `.env` file co-located with the Quadlet units that supplies secrets and configuration values to all containers.
- **Named_Volume**: A Podman-managed named volume (defined via a `.volume` Quadlet unit) used for persistent PostgreSQL data.
- **Healthcheck**: A periodic command run inside a container to determine whether the service it hosts is ready to accept connections.

---

## Requirements

### Requirement 1: Quadlet Unit File Generation

**User Story:** As a system administrator, I want three Podman Quadlet unit files (one per service), so that each container is managed as an independent rootless systemd service.

#### Acceptance Criteria

1. THE Authentik_Stack SHALL be defined using exactly three Quadlet `.container` unit files: `postgresql.container`, `authentik-server.container`, and `authentik-worker.container`.
2. THE Authentik_Stack SHALL include a Quadlet `.volume` unit file (`authentik-database.volume`) that declares the named volume used by PostgreSQL_Container.
3. WHEN `systemctl --user daemon-reload` is executed, THE Quadlet_Unit files SHALL be processed by `podman-system-generator` without errors and produce corresponding `.service` units.
4. THE Authentik_Stack unit files SHALL be placed under `~/.config/containers/systemd/` so that they are discovered by the user-level systemd instance.

---

### Requirement 2: Rootless Execution

**User Story:** As a security-conscious operator, I want all containers to run under a non-root host user, so that a container escape does not grant root access to the host.

#### Acceptance Criteria

1. THE Authentik_Stack SHALL be managed exclusively by `systemctl --user` (the user-level systemd instance), with no unit files installed in the system-level `/etc/systemd/system/` directory.
2. THE PostgreSQL_Container SHALL run without the `User=root` directive in its Quadlet unit.
3. THE Server_Container SHALL run without the `User=root` directive in its Quadlet unit.
4. THE Worker_Container SHALL run without the `User=root` directive in its Quadlet unit.

---

### Requirement 3: Service Start Order and Dependency Enforcement

**User Story:** As an operator, I want the server and worker containers to start only after PostgreSQL is healthy, so that Authentik does not attempt to connect to an unavailable database.

#### Acceptance Criteria

1. THE Server_Container SHALL declare `After=postgresql.service` and `Requires=postgresql.service` (or equivalent Quadlet dependency directives) in its unit.
2. THE Worker_Container SHALL declare `After=postgresql.service` and `Requires=postgresql.service` (or equivalent Quadlet dependency directives) in its unit.
3. WHEN PostgreSQL_Container has not yet passed its Healthcheck, THE Server_Container SHALL remain in the `waiting` state and SHALL NOT attempt to start. To enforce this, a wrapper `oneshot` systemd service (`postgresql-healthy.service`) SHALL be used; this service runs `podman healthcheck run postgresql` in a loop and exits successfully only once the Healthcheck passes. THE Server_Container SHALL declare `After=postgresql-healthy.service` and `Requires=postgresql-healthy.service` instead of depending directly on `postgresql.service`.
4. WHEN PostgreSQL_Container has not yet passed its Healthcheck, THE Worker_Container SHALL remain in the `waiting` state and SHALL NOT attempt to start. THE Worker_Container SHALL declare `After=postgresql-healthy.service` and `Requires=postgresql-healthy.service` instead of depending directly on `postgresql.service`.
5. THE PostgreSQL_Container SHALL expose a Healthcheck that runs `pg_isready -d $POSTGRES_DB -U $POSTGRES_USER` with an interval of 30 seconds, a timeout of 5 seconds, a start period of 20 seconds, and a maximum of 5 retries.
6. WHEN PostgreSQL_Container fails its Healthcheck after all retries are exhausted, THE Server_Container and Worker_Container SHALL not be started by systemd.

---

### Requirement 4: Environment and Secret Configuration

**User Story:** As an operator, I want all secrets and environment variables loaded from a single `.env` file, so that credentials are not embedded in the unit files.

#### Acceptance Criteria

1. THE PostgreSQL_Container SHALL load environment variables from the Env_File using the Quadlet `EnvironmentFile=` directive.
2. THE Server_Container SHALL load environment variables from the Env_File using the Quadlet `EnvironmentFile=` directive.
3. THE Worker_Container SHALL load environment variables from the Env_File using the Quadlet `EnvironmentFile=` directive.
4. THE PostgreSQL_Container SHALL set `POSTGRES_DB`, `POSTGRES_PASSWORD`, and `POSTGRES_USER` with the same default values as the original Compose setup (`authentik` for DB and user; no default for password).
5. THE Server_Container SHALL set `AUTHENTIK_POSTGRESQL__HOST`, `AUTHENTIK_POSTGRESQL__NAME`, `AUTHENTIK_POSTGRESQL__PASSWORD`, `AUTHENTIK_POSTGRESQL__USER`, and `AUTHENTIK_SECRET_KEY` environment variables.
6. THE Worker_Container SHALL set the same five environment variables as the Server_Container.
7. IF the Env_File is absent at service start time, THEN THE Authentik_Stack SHALL fail to start and systemd SHALL report a descriptive unit activation error.

---

### Requirement 5: Volume and Bind-Mount Configuration

**User Story:** As an operator, I want persistent data, certificates, and custom templates to be stored in predictable locations, so that data survives container restarts and image updates.

#### Acceptance Criteria

1. THE PostgreSQL_Container SHALL mount the Named_Volume (`authentik-database`) at `/var/lib/postgresql/data` inside the container.
2. THE Server_Container SHALL bind-mount the host directory `%h/authentik/data` to `/data` inside the container.
3. THE Server_Container SHALL bind-mount the host directory `%h/authentik/custom-templates` to `/templates` inside the container.
4. THE Worker_Container SHALL bind-mount the host directory `%h/authentik/data` to `/data` inside the container.
5. THE Worker_Container SHALL bind-mount the host directory `%h/authentik/certs` to `/certs` inside the container.
6. THE Worker_Container SHALL bind-mount the host directory `%h/authentik/custom-templates` to `/templates` inside the container.
7. THE Named_Volume SHALL be declared in `authentik-database.volume` and referenced by name in the PostgreSQL_Container unit so that Podman manages volume lifecycle independently of the container.

---

### Requirement 6: Network Configuration and Inter-Container Communication

**User Story:** As an operator, I want the three containers to communicate with each other over a private network, so that the database port is not exposed on the host.

#### Acceptance Criteria

1. THE Authentik_Stack SHALL define a dedicated Podman network (via a `.network` Quadlet unit or inline network declaration) that all three containers join.
2. THE Server_Container SHALL reach PostgreSQL_Container using the hostname `postgresql` (matching the container name used in `AUTHENTIK_POSTGRESQL__HOST`).
3. THE Worker_Container SHALL reach PostgreSQL_Container using the hostname `postgresql`.
4. THE PostgreSQL_Container SHALL NOT expose any ports on the host interface.
5. THE Server_Container SHALL publish port `127.0.0.1:9000:9000` with no environment variable substitution.

---

### Requirement 7: Shared Memory Configuration

**User Story:** As an operator, I want the server and worker containers to have 512 MB of shared memory, so that Authentik's internal processes have sufficient `/dev/shm` space.

#### Acceptance Criteria

1. THE Server_Container SHALL be configured with a shared memory size of 512 MB (equivalent to `--shm-size=512m`).
2. THE Worker_Container SHALL be configured with a shared memory size of 512 MB (equivalent to `--shm-size=512m`).

---

### Requirement 8: Automatic Restart Policy

**User Story:** As an operator, I want all containers to restart automatically unless explicitly stopped, so that the Authentik stack recovers from transient failures without manual intervention.

#### Acceptance Criteria

1. THE PostgreSQL_Container SHALL set `Restart=always` (or the Quadlet equivalent that maps to `--restart=unless-stopped` behaviour) in its systemd unit.
2. THE Server_Container SHALL set `Restart=always` in its systemd unit.
3. THE Worker_Container SHALL set `Restart=always` in its systemd unit.
4. WHEN a container exits with a non-zero exit code, THE Authentik_Stack SHALL restart the affected container automatically without operator intervention.

---

### Requirement 9: PostgreSQL Minor-Version Auto-Update

**User Story:** As an operator, I want PostgreSQL to automatically update to the latest patch release within the `16-alpine` tag series, so that security fixes are applied without manual image pulls.

#### Acceptance Criteria

1. THE PostgreSQL_Container SHALL set the container label `io.containers.autoupdate=registry` so that `podman auto-update` checks for a newer digest of the `docker.io/library/postgres:16-alpine` image.
2. WHEN `podman auto-update` is executed and a newer digest exists for `postgres:16-alpine`, THE PostgreSQL_Container SHALL pull the new image and restart the container.
3. THE PostgreSQL_Container image tag SHALL remain pinned to `16-alpine` (a floating minor-version tag) and SHALL NOT be automatically changed to a different major version tag (e.g., `17-alpine`).
4. WHERE a systemd timer is used to schedule auto-updates, THE timer SHALL run `podman auto-update` on a regular cadence (at minimum daily).

---

### Requirement 10: Authentik Server and Worker Controlled Update Process

**User Story:** As an operator, I want to control when the Authentik server and worker update to a new patch release, so that I can review the changelog for breaking changes before applying an update.

#### Acceptance Criteria

1. THE Server_Container and Worker_Container image tag SHALL be set to the floating minor-version tag `2026.2`, so that new patch releases (e.g., `2026.2.1`, `2026.2.2`, `2026.2.3`) are available for update without changing the tag.
2. THE Server_Container SHALL NOT set `AutoUpdate=registry`; automatic unattended updates for Authentik containers are intentionally disabled.
3. THE Worker_Container SHALL NOT set `AutoUpdate=registry`; automatic unattended updates for Authentik containers are intentionally disabled.
4. WHEN an operator wishes to update Authentik, they SHALL run `podman pull ghcr.io/goauthentik/server:2026.2` to fetch the latest digest, review the Authentik changelog, then restart the server and worker services with `systemctl --user restart authentik-server.service authentik-worker.service`.
5. THE Server_Container and Worker_Container image tag SHALL NOT be automatically changed to a different minor or major version (e.g., `2026.3` or `2027.1`); such upgrades require a manual tag change in the unit files.
