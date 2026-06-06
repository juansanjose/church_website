#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${ROOT_DIR}/wp-content/themes" \
  "${ROOT_DIR}/wp-content/plugins" \
  "${ROOT_DIR}/dumps" \
  "${ROOT_DIR}/backups" \
  "${ROOT_DIR}/logs"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  printf 'Created .env from .env.example. Fill it in before pulling or deploying.\n'
else
  printf '.env already exists.\n'
fi

printf 'Runtime directories are ready.\n'
