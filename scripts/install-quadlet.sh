#!/usr/bin/env bash
# Install rootless Quadlet units and runtime config for FOAH RSS.

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

QUADLET_DIR="${DEPLOY_DIR}/quadlet"
QUADLET_USER_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/containers/systemd"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/foah-rss"

write_env_file() {
  local destination="$1"
  shift

  umask 077
  : >"$destination"

  local name
  for name in "$@"; do
    if [[ -n "${!name+x}" ]]; then
      printf '%s=%s\n' "$name" "${!name}" >>"$destination"
    fi
  done
}

write_postgres_env_file() {
  umask 077
  {
    printf 'POSTGRES_DB=%s\n' "${POSTGRES_DB:-miniflux}"
    printf 'POSTGRES_USER=%s\n' "${POSTGRES_USER:-miniflux}"
    printf 'POSTGRES_PASSWORD=%s\n' "$POSTGRES_PASSWORD"
    printf 'TZ=%s\n' "${TZ:-UTC}"
    printf 'FOAH_RSS_PGBACKREST_ENABLED=%s\n' "${PGBACKREST_ENABLED:-0}"
    printf 'PGBACKREST_STANZA=%s\n' "${PGBACKREST_STANZA:-foah_rss}"
    printf 'PGBACKREST_PG1_PATH=%s\n' "/var/lib/postgresql/18/docker"
    printf 'PGBACKREST_PG1_USER=%s\n' "${POSTGRES_USER:-miniflux}"
    printf 'PGBACKREST_REPO1_TYPE=%s\n' "s3"
    printf 'PGBACKREST_REPO1_PATH=%s\n' "${BACKUP_REPO_PATH:-/foah-rss}"
    printf 'PGBACKREST_REPO1_S3_BUCKET=%s\n' "${BACKUP_S3_BUCKET:-}"
    printf 'PGBACKREST_REPO1_S3_KEY=%s\n' "${BACKUP_S3_ACCESS_KEY_ID:-}"
    printf 'PGBACKREST_REPO1_S3_KEY_SECRET=%s\n' "${BACKUP_S3_SECRET_ACCESS_KEY:-}"
    printf 'PGBACKREST_REPO1_S3_ENDPOINT=%s\n' "${BACKUP_S3_ENDPOINT:-s3.amazonaws.com}"
    printf 'PGBACKREST_REPO1_S3_REGION=%s\n' "${BACKUP_S3_REGION:-us-east-1}"
    printf 'PGBACKREST_REPO1_S3_URI_STYLE=%s\n' "${BACKUP_S3_URI_STYLE:-host}"
    printf 'PGBACKREST_REPO1_CIPHER_TYPE=%s\n' "${BACKUP_CIPHER_TYPE:-aes-256-cbc}"
    printf 'PGBACKREST_REPO1_CIPHER_PASS=%s\n' "${BACKUP_CIPHER_PASS:-}"
    printf 'PGBACKREST_REPO1_RETENTION_FULL=%s\n' "${BACKUP_RETENTION_FULL:-4}"
    printf 'PGBACKREST_REPO1_RETENTION_FULL_TYPE=%s\n' "count"
    printf 'PGBACKREST_REPO1_RETENTION_ARCHIVE_TYPE=%s\n' "full"
    printf 'PGBACKREST_PROCESS_MAX=%s\n' "${BACKUP_PROCESS_MAX:-2}"
  } >"${CONFIG_DIR}/postgres.env"
}

write_miniflux_env_file() {
  umask 077
  {
    printf 'DATABASE_URL=postgres://%s:%s@foah-rss-postgres:5432/%s?sslmode=disable\n' \
      "${POSTGRES_USER:-miniflux}" \
      "$POSTGRES_PASSWORD" \
      "${POSTGRES_DB:-miniflux}"
    printf 'RUN_MIGRATIONS=1\n'
    printf 'CREATE_ADMIN=%s\n' "${MINIFLUX_CREATE_ADMIN:-1}"
    printf 'ADMIN_USERNAME=%s\n' "$MINIFLUX_ADMIN_USERNAME"
    printf 'ADMIN_PASSWORD=%s\n' "$MINIFLUX_ADMIN_PASSWORD"
    printf 'BASE_URL=https://%s\n' "$RSS_DOMAIN"
    printf 'HTTPS=1\n'
    printf 'LOG_DATE_TIME=1\n'
    printf 'LOG_FORMAT=json\n'
    printf 'POLLING_FREQUENCY=%s\n' "${MINIFLUX_POLLING_FREQUENCY:-30}"
    printf 'BATCH_SIZE=%s\n' "${MINIFLUX_BATCH_SIZE:-50}"
    printf 'POLLING_LIMIT_PER_HOST=%s\n' "${MINIFLUX_POLLING_LIMIT_PER_HOST:-2}"
  } >"${CONFIG_DIR}/miniflux.env"
}

require_env_file
require_command systemctl
require_env_vars \
  RSS_DOMAIN \
  POSTGRES_PASSWORD \
  MINIFLUX_ADMIN_USERNAME \
  MINIFLUX_ADMIN_PASSWORD

if is_truthy "${PGBACKREST_ENABLED:-0}"; then
  require_env_vars \
    BACKUP_S3_BUCKET \
    BACKUP_S3_ACCESS_KEY_ID \
    BACKUP_S3_SECRET_ACCESS_KEY \
    BACKUP_CIPHER_PASS
fi

mkdir -p "$QUADLET_USER_DIR" "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

write_postgres_env_file
write_miniflux_env_file
printf 'FOAH_RSS_DEPLOY_DIR=%s\n' "$DEPLOY_DIR" >"${CONFIG_DIR}/deploy.env"

find "$QUADLET_DIR" -maxdepth 1 -type f -exec install -m 644 -t "$QUADLET_USER_DIR" {} +

systemctl_user daemon-reload
systemctl_user enable foah-rss-postgres.service foah-rss-miniflux.service

log "Installed rootless Quadlets in ${QUADLET_USER_DIR}"
log "Installed runtime config in ${CONFIG_DIR}"
