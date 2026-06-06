#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
require_command docker
require_var LIVE_URL
require_var LOCAL_URL

ensure_runtime_dirs

timestamp="$(date +%Y%m%d-%H%M%S)"
local_dump="${ROOT_DIR}/dumps/live-${timestamp}.sql"

if [[ "$(live_access)" == "rest" ]]; then
  require_command curl
  require_var LIVE_ADMIN_USER
  require_var LIVE_APP_PASSWORD

  info "Downloading live database through REST bridge"
  api_get "/export-db" "${local_dump}"
else
  require_command ssh
  require_command rsync
  require_var LIVE_HOST
  require_var LIVE_USER
  require_var LIVE_PATH

  remote_dump="/tmp/wp-${timestamp}.sql"

  info "Exporting live database to ${remote_dump}"
  remote_wp "db export '${remote_dump}' --add-drop-table"

  info "Downloading database dump"
  rsync -az -e "$(rsync_ssh_arg)" "$(ssh_target):${remote_dump}" "${local_dump}"

  info "Removing remote database dump"
  ssh_args="$(ssh_base)"
  # shellcheck disable=SC2086
  ssh ${ssh_args} "$(ssh_target)" "rm -f '${remote_dump}'"
fi

info "Starting local containers"
compose_cmd up -d db wordpress

table_prefix="$(sed -n 's/^CREATE TABLE `\([^`]*_\).*$/\1/p' "${local_dump}" | head -n 1)"
if [[ -n "${WORDPRESS_TABLE_PREFIX:-}" ]]; then
  table_prefix="${WORDPRESS_TABLE_PREFIX}"
fi
if [[ -n "${table_prefix}" ]]; then
  info "Setting local WordPress table prefix to ${table_prefix}"
  compose_cmd run --rm "${WPCLI_SERVICE:-wpcli}" config set table_prefix "${table_prefix}" --type=variable || true
fi

info "Importing database locally"
compose_cmd run --rm "${WPCLI_SERVICE:-wpcli}" db import "/dumps/$(basename "${local_dump}")"

info "Replacing live URL with local URL"
compose_cmd run --rm "${WPCLI_SERVICE:-wpcli}" search-replace "${LIVE_URL}" "${LOCAL_URL}" --all-tables --skip-columns=guid

info "Updating local siteurl and home"
compose_cmd run --rm "${WPCLI_SERVICE:-wpcli}" option update siteurl "${LOCAL_URL}"
compose_cmd run --rm "${WPCLI_SERVICE:-wpcli}" option update home "${LOCAL_URL}"

info "Database pull complete: ${local_dump}"
