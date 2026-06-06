#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

mode="${1:---dry-run}"
case "${mode}" in
  --dry-run) dry_run=(--dry-run) ;;
  --apply) dry_run=() ;;
  *) die "usage: $0 [--dry-run|--apply]" ;;
esac

load_env
require_command zip

theme_slug="$(detect_theme_slug)"
[[ -n "${theme_slug}" ]] || die "could not detect active theme. Set THEME_SLUG in .env."

if [[ "$(live_access)" == "rest" ]]; then
  require_command curl
  require_var LIVE_URL
  require_var LIVE_ADMIN_USER
  require_var LIVE_APP_PASSWORD

  package_dir="${ROOT_DIR}/dumps/deploy"
  mkdir -p "${package_dir}"

  deploy_rest_path() {
    local type="$1"
    local slug="$2"
    local local_path="$3"
    local zip_file="${package_dir}/${type}-${slug}.zip"

    [[ -d "${local_path}" ]] || die "local ${type} path does not exist: ${local_path}"

    info "Packaging ${type}: ${slug}"
    rm -f "${zip_file}"
    (cd "$(dirname "${local_path}")" && zip -qr "${zip_file}" "$(basename "${local_path}")" -x '*/.git/*' '*/node_modules/*' '*/vendor/*' '*.sql' '*.sql.gz')

    if [[ "${mode}" == "--dry-run" ]]; then
      info "Dry-run REST mode: package created at ${zip_file}; no production files changed."
    else
      info "Uploading ${type} through REST bridge: ${slug}"
      api_post_file "/deploy-code" "${zip_file}" "${type}" "${slug}"
      printf '\n'
    fi
  }

  deploy_rest_path "theme" "${theme_slug}" "${ROOT_DIR}/wp-content/themes/${theme_slug}"

  if [[ -n "${DEPLOY_PLUGIN_SLUGS:-}" ]]; then
    for plugin_slug in ${DEPLOY_PLUGIN_SLUGS}; do
      deploy_rest_path "plugin" "${plugin_slug}" "${ROOT_DIR}/wp-content/plugins/${plugin_slug}"
    done
  fi

  info "Deploy ${mode#--} complete."
  exit 0
fi

require_command ssh
require_command rsync
require_var LIVE_HOST
require_var LIVE_USER
require_var LIVE_PATH

rsync_ssh="$(rsync_ssh_arg)"
remote="$(ssh_target)"

deploy_path() {
  local label="$1"
  local local_path="$2"
  local remote_path="$3"

  [[ -d "${local_path}" ]] || die "local ${label} path does not exist: ${local_path}"

  info "Deploying ${label}: ${local_path} -> ${remote}:${remote_path}"
  rsync -az --delete "${dry_run[@]}" \
    -e "${rsync_ssh}" \
    --exclude='.git/' \
    --exclude='.env' \
    --exclude='node_modules/' \
    --exclude='vendor/' \
    --exclude='*.sql' \
    --exclude='*.sql.gz' \
    "${local_path}/" \
    "${remote}:${remote_path}/"
}

if [[ "${mode}" == "--dry-run" ]]; then
  info "Dry-run mode. No production files will be changed."
else
  info "Apply mode. Production files will be updated."
fi

deploy_path "theme ${theme_slug}" \
  "${ROOT_DIR}/wp-content/themes/${theme_slug}" \
  "${LIVE_PATH}/wp-content/themes/${theme_slug}"

if [[ -n "${DEPLOY_PLUGIN_SLUGS:-}" ]]; then
  for plugin_slug in ${DEPLOY_PLUGIN_SLUGS}; do
    deploy_path "plugin ${plugin_slug}" \
      "${ROOT_DIR}/wp-content/plugins/${plugin_slug}" \
      "${LIVE_PATH}/wp-content/plugins/${plugin_slug}"
  done
fi

info "Deploy ${mode#--} complete."
