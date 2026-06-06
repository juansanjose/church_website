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

uploads_zip="${ROOT_DIR}/dumps/uploads.zip"
info "Downloading live uploads through REST bridge"
api_get "/export-uploads" "${uploads_zip}"

info "Extracting uploads into wp-content/uploads"
mkdir -p "${ROOT_DIR}/wp-content"
unzip -oq "${uploads_zip}" -d "${ROOT_DIR}/wp-content"

info "Uploads pull complete."
