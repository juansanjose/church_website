#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="${ROOT_DIR}/tools/wp-local-dev-bridge"
OUT_DIR="${ROOT_DIR}/dumps"
OUT_FILE="${OUT_DIR}/wp-local-dev-bridge.zip"

command -v zip >/dev/null 2>&1 || {
  printf 'Error: required command not found: zip\n' >&2
  exit 1
}

mkdir -p "${OUT_DIR}"
rm -f "${OUT_FILE}"

(cd "${ROOT_DIR}/tools" && zip -qr "${OUT_FILE}" "$(basename "${PLUGIN_DIR}")")

printf 'Bridge plugin package created: %s\n' "${OUT_FILE}"
printf 'Upload it in wp-admin: Plugins > Add Plugin > Upload Plugin, then activate it.\n'
