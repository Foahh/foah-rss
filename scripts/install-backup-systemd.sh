#!/usr/bin/env bash
# Install user-level pgBackRest backup timers for FOAH RSS.

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/foah-rss"

require_env_file
require_command systemctl

mkdir -p "$UNIT_DIR" "$CONFIG_DIR"
printf 'FOAH_RSS_DEPLOY_DIR=%s\n' "$DEPLOY_DIR" >"${CONFIG_DIR}/deploy.env"

install -m 644 "${DEPLOY_DIR}/systemd/foah-rss-backup@.service" "$UNIT_DIR/foah-rss-backup@.service"
install -m 644 "${DEPLOY_DIR}/systemd/foah-rss-backup-diff.timer" "$UNIT_DIR/foah-rss-backup-diff.timer"
install -m 644 "${DEPLOY_DIR}/systemd/foah-rss-backup-full.timer" "$UNIT_DIR/foah-rss-backup-full.timer"

systemctl_user daemon-reload

if is_truthy "${PGBACKREST_ENABLED:-0}"; then
  systemctl_user enable --now foah-rss-backup-diff.timer foah-rss-backup-full.timer
  log "Enabled FOAH RSS pgBackRest backup timers"
else
  log "Skipped backup timers because PGBACKREST_ENABLED is off"
fi
