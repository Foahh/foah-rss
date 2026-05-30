#!/usr/bin/env sh
set -eu

case "${FOAH_RSS_PGBACKREST_ENABLED:-0}" in
  1 | true | TRUE | yes | YES | on | ON) ;;
  *) exit 0 ;;
esac

exec pgbackrest --stanza="${PGBACKREST_STANZA:-foah_rss}" archive-push "$1"
