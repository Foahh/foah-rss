#!/usr/bin/env bash
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib/common.sh"

log "Deploying FOAH RSS..."

require_env_file
require_podman
require_command systemctl

bash "${DEPLOY_DIR}/scripts/install-quadlet.sh"
bash "${DEPLOY_DIR}/scripts/install-backup-systemd.sh"

POSTGRES_IMAGE="localhost/foah-rss/postgres-pgbackrest:current"
MINIFLUX_IMAGE="docker.io/miniflux/miniflux:${MINIFLUX_VERSION:-2.3.1}"

log "Building pgBackRest-enabled postgres image..."
podman_cmd build \
  -t "$POSTGRES_IMAGE" \
  --build-arg "POSTGRES_VERSION=${POSTGRES_VERSION:-18}" \
  -f "${DEPLOY_DIR}/docker/postgres.Dockerfile" \
  "$DEPLOY_DIR"

log "Pulling Miniflux image..."
podman_cmd pull "$MINIFLUX_IMAGE"
podman_cmd tag "$MINIFLUX_IMAGE" localhost/foah-rss/miniflux:current

log "Starting postgres..."
systemctl_user restart foah-rss-postgres.service
wait_for_postgres

if is_truthy "${PGBACKREST_ENABLED:-0}"; then
  log "Ensuring pgBackRest stanza exists: ${PGBACKREST_STANZA:-foah_rss}"
  run_pgbackrest "${PGBACKREST_STANZA:-foah_rss}" stanza-create
fi

log "Starting Miniflux..."
systemctl_user restart foah-rss-miniflux.service

log "Deployment complete."
