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

if [[ "$(live_access)" == "rest" ]]; then
  require_command curl
  require_var LIVE_ADMIN_USER
  require_var LIVE_APP_PASSWORD

  info "Checking WordPress REST bridge at $(api_base)/status..."
  curl --fail --show-error --location -u "${LIVE_ADMIN_USER}:${LIVE_APP_PASSWORD}" "$(api_base)/status" >/dev/null
else
  require_command ssh
  require_command rsync
  require_var LIVE_HOST
  require_var LIVE_USER
  require_var LIVE_PATH

  info "Checking SSH access to $(ssh_target)..."
  ssh_args="$(ssh_base)"
  # shellcheck disable=SC2086
  ssh ${ssh_args} "$(ssh_target)" "test -d '${LIVE_PATH}' && cd '${LIVE_PATH}' && ${REMOTE_WP:-wp} --info >/dev/null"
fi

info "Checking Docker Compose..."
compose_cmd version >/dev/null

info "Environment check passed."
