#!/usr/bin/env bash
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib/common.sh"

if ! is_truthy "${PGBACKREST_ENABLED:-0}"; then
  log "Skipping pgBackRest backup because PGBACKREST_ENABLED is off"
  exit 0
fi

require_podman
require_env_vars \
  POSTGRES_USER \
  POSTGRES_DB \
  BACKUP_S3_BUCKET \
  BACKUP_S3_ACCESS_KEY_ID \
  BACKUP_S3_SECRET_ACCESS_KEY \
  BACKUP_CIPHER_PASS

BACKUP_TYPE="${1:-${BACKUP_TYPE:-diff}}"
case "$BACKUP_TYPE" in
  full | diff | incr) ;;
  *) die "Backup type must be one of: full, diff, incr." ;;
esac

STANZA="${PGBACKREST_STANZA:-foah_rss}"

wait_for_postgres

log "Ensuring pgBackRest stanza exists: ${STANZA}"
run_pgbackrest "$STANZA" stanza-create

log "Checking pgBackRest stanza: ${STANZA}"
if ! run_pgbackrest "$STANZA" check; then
  log "Postgres archiver status:"
  podman_exec_postgres sh -c \
    'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "select archived_count, failed_count, last_archived_wal, last_failed_wal, last_failed_time from pg_stat_archiver;"'

  log "Recent postgres logs:"
  podman_cmd logs --tail=80 "$(postgres_container)"

  log "Recent pgBackRest logs:"
  podman_exec_postgres sh -c 'tail -n 120 /var/log/pgbackrest/*.log 2>/dev/null || true'

  exit 1
fi

log "Running pgBackRest ${BACKUP_TYPE} backup for stanza: ${STANZA}"
run_pgbackrest "$STANZA" --type="$BACKUP_TYPE" backup

log "Expiring old pgBackRest backups using configured retention"
run_pgbackrest "$STANZA" expire

log "Done (pgBackRest): ${STANZA}"
