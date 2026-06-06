#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
require_command curl
require_command unzip
require_var LIVE_URL
require_var LIVE_ADMIN_USER
require_var LIVE_APP_PASSWORD

ensure_runtime_dirs

languages_zip="${ROOT_DIR}/dumps/languages.zip"
info "Downloading live languages through REST bridge"
api_get "/export-languages" "${languages_zip}"

info "Extracting languages into wp-content/languages"
mkdir -p "${ROOT_DIR}/wp-content"
unzip -oq "${languages_zip}" -d "${ROOT_DIR}/wp-content"

info "Languages pull complete."
