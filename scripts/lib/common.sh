set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[1]}")"
DEPLOY_DIR="$SCRIPT_DIR"
while [[ "$DEPLOY_DIR" != "/" && ! -d "${DEPLOY_DIR}/quadlet" ]]; do
  DEPLOY_DIR="$(dirname "$DEPLOY_DIR")"
done
[[ -d "${DEPLOY_DIR}/quadlet" ]] || DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() {
  printf '[%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")" "$*"
}

die() {
  log "$*" >&2
  exit 1
}

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | on | ON) return 0 ;;
    *) return 1 ;;
  esac
}

load_env() {
  local env_file="${1:-${DEPLOY_DIR}/.env}"

  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

require_env_file() {
  local env_file="${1:-${DEPLOY_DIR}/.env}"
  [[ -f "$env_file" ]] || die ".env not found in ${DEPLOY_DIR}"
}

require_env_vars() {
  local name

  for name in "$@"; do
    [[ -n "${!name:-}" ]] || die "${name} is required."
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required."
}

require_podman() {
  require_command "${PODMAN_BIN:-podman}"
}

podman_cmd() {
  "${PODMAN_BIN:-podman}" "$@"
}

configure_user_systemd_env() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    if [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
      export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
    fi
  fi
}

systemctl_user() {
  systemctl --user "$@"
}

postgres_container() {
  printf '%s\n' "${FOAH_RSS_POSTGRES_CONTAINER:-foah-rss-postgres}"
}

podman_exec_postgres() {
  podman_cmd exec -i "$(postgres_container)" "$@"
}

podman_exec_postgres_user() {
  podman_cmd exec -i --user postgres "$(postgres_container)" "$@"
}

wait_for_postgres() {
  local attempts="${1:-30}"
  local attempt

  log "Waiting for postgres to accept connections..."
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    if podman_exec_postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q; then
      return 0
    fi

    if [[ "$attempt" -eq "$attempts" ]]; then
      die "Postgres did not become ready in time."
    fi

    sleep 2
  done
}

run_pgbackrest() {
  local stanza="$1"
  shift

  podman_exec_postgres_user pgbackrest --stanza="$stanza" "$@"
}

cd "$DEPLOY_DIR"
load_env
configure_user_systemd_env
