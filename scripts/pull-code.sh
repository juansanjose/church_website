#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

load_env
require_command unzip

ensure_runtime_dirs

theme_slug="$(detect_theme_slug)"
[[ -n "${theme_slug}" ]] || die "could not detect active theme. Set THEME_SLUG in .env."

if [[ "$(live_access)" == "rest" ]]; then
  require_command curl
  require_var LIVE_URL
  require_var LIVE_ADMIN_USER
  require_var LIVE_APP_PASSWORD

  theme_zip="${ROOT_DIR}/dumps/theme-${theme_slug}.zip"
  info "Pulling theme through REST bridge: ${theme_slug}"
  api_get "/export-code?type=theme&slug=${theme_slug}" "${theme_zip}"
  unzip -oq "${theme_zip}" -d "${ROOT_DIR}/wp-content/themes"

  if [[ -n "${PLUGIN_SLUGS:-}" ]]; then
    for plugin_slug in ${PLUGIN_SLUGS}; do
      plugin_zip="${ROOT_DIR}/dumps/plugin-${plugin_slug}.zip"
      info "Pulling plugin through REST bridge: ${plugin_slug}"
      api_get "/export-code?type=plugin&slug=${plugin_slug}" "${plugin_zip}"
      unzip -oq "${plugin_zip}" -d "${ROOT_DIR}/wp-content/plugins"
    done
  fi

  info "Code pull complete."
  exit 0
fi

require_command ssh
require_command rsync
require_var LIVE_HOST
require_var LIVE_USER
require_var LIVE_PATH

rsync_ssh="$(rsync_ssh_arg)"
remote="$(ssh_target)"

info "Pulling theme: ${theme_slug}"
rsync -az --delete \
  -e "${rsync_ssh}" \
  --exclude='.git/' \
  --exclude='node_modules/' \
  --exclude='vendor/' \
  "${remote}:${LIVE_PATH}/wp-content/themes/${theme_slug}/" \
  "${ROOT_DIR}/wp-content/themes/${theme_slug}/"

if [[ -n "${PLUGIN_SLUGS:-}" ]]; then
  for plugin_slug in ${PLUGIN_SLUGS}; do
    info "Pulling plugin: ${plugin_slug}"
    mkdir -p "${ROOT_DIR}/wp-content/plugins/${plugin_slug}"
    rsync -az --delete \
      -e "${rsync_ssh}" \
      --exclude='.git/' \
      --exclude='node_modules/' \
      --exclude='vendor/' \
      "${remote}:${LIVE_PATH}/wp-content/plugins/${plugin_slug}/" \
      "${ROOT_DIR}/wp-content/plugins/${plugin_slug}/"
  done
fi

info "Code pull complete."
