#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    die "missing .env. Run: cp .env.example .env, then fill in the live site values."
  fi

  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    die "missing required .env value: ${name}"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

live_access() {
  printf '%s' "${LIVE_ACCESS:-ssh}"
}

compose_cmd() {
  docker compose "$@"
}

ssh_base() {
  local args=(-p "${LIVE_PORT:-22}")
  if [[ -n "${SSH_KEY:-}" ]]; then
    args+=(-i "${SSH_KEY}")
  fi
  printf '%q ' "${args[@]}"
}

ssh_target() {
  printf '%s@%s' "${LIVE_USER}" "${LIVE_HOST}"
}

remote_wp() {
  local ssh_args
  ssh_args="$(ssh_base)"
  # shellcheck disable=SC2086
  ssh ${ssh_args} "$(ssh_target)" "cd '${LIVE_PATH}' && ${REMOTE_WP:-wp} $*"
}

api_base() {
  printf '%s/wp-json/local-dev/v1' "${LIVE_URL%/}"
}

api_get() {
  local endpoint="$1"
  local output="$2"
  shift 2

  curl --fail --show-error --location -u "${LIVE_ADMIN_USER}:${LIVE_APP_PASSWORD}" "$@" \
    "$(api_base)${endpoint}" \
    --output "${output}"
}

api_post_file() {
  local endpoint="$1"
  local file="$2"
  local type="$3"
  local slug="$4"

  curl --fail --show-error --location -u "${LIVE_ADMIN_USER}:${LIVE_APP_PASSWORD}" \
    -F "package=@${file}" \
    -F "type=${type}" \
    -F "slug=${slug}" \
    "$(api_base)${endpoint}"
}

rsync_ssh_arg() {
  local ssh_cmd="ssh -p ${LIVE_PORT:-22}"
  if [[ -n "${SSH_KEY:-}" ]]; then
    ssh_cmd="${ssh_cmd} -i ${SSH_KEY}"
  fi
  printf '%s' "${ssh_cmd}"
}

detect_theme_slug() {
  if [[ -n "${THEME_SLUG:-}" ]]; then
    printf '%s\n' "${THEME_SLUG}"
    return
  fi

  if [[ "$(live_access)" == "rest" ]]; then
    require_command curl
    require_var LIVE_URL
    require_var LIVE_ADMIN_USER
    require_var LIVE_APP_PASSWORD
    curl --fail --silent --show-error --location -u "${LIVE_ADMIN_USER}:${LIVE_APP_PASSWORD}" "$(api_base)/status" \
      | sed -n 's/.*"active_theme"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    return
  fi

  remote_wp "theme list --status=active --field=name" | tr -d '\r' | tail -n 1
}

ensure_runtime_dirs() {
  mkdir -p "${ROOT_DIR}/wp-content/themes" \
    "${ROOT_DIR}/wp-content/plugins" \
    "${ROOT_DIR}/dumps" \
    "${ROOT_DIR}/backups" \
    "${ROOT_DIR}/logs"
}

common_rsync_excludes() {
  printf '%s\n' \
    '--exclude=.env' \
    '--exclude=.git/' \
    '--exclude=node_modules/' \
    '--exclude=vendor/' \
    '--exclude=*.sql' \
    '--exclude=*.sql.gz' \
    '--exclude=.DS_Store'
}
