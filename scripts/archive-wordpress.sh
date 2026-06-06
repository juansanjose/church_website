#!/usr/bin/env bash
# ========================================
# Archive WordPress Legacy Code
# Run AFTER successful migration validation
# ========================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_DIR="${PROJECT_ROOT}/archive/legacy-wordpress"
DUMP_DIR="${PROJECT_ROOT}/dumps"

echo "[INFO] Archiving WordPress legacy code..."

# Create archive directory structure
mkdir -p "${ARCHIVE_DIR}"/{wp-content,dumps,config-backup}

# Preserve database dumps
echo "[INFO] Preserving database dumps..."
cp -a "${DUMP_DIR}"/live-*.sql "${ARCHIVE_DIR}/dumps/" 2>/dev/null || true
cp -a "${DUMP_DIR}"/*.sql "${ARCHIVE_DIR}/dumps/" 2>/dev/null || true

# Preserve wp-config.php if it exists
if [[ -f "${PROJECT_ROOT}/wp-config.php" ]]; then
  echo "[INFO] Preserving wp-config.php (sanitizing credentials)..."
  sed 's/define.*DB_PASSWORD.*/define("DB_PASSWORD", "***REDACTED***");/' "${PROJECT_ROOT}/wp-config.php" > "${ARCHIVE_DIR}/config-backup/wp-config.php.sanitized"
  cp "${PROJECT_ROOT}/wp-config.php" "${ARCHIVE_DIR}/config-backup/wp-config.php.original"
fi

# Preserve uploads backup
if [[ -d "${PROJECT_ROOT}/wp-content/uploads" ]]; then
  echo "[INFO] Preserving uploads backup..."
  cp -a "${PROJECT_ROOT}/wp-content/uploads" "${ARCHIVE_DIR}/wp-content/"
fi

# Preserve languages
if [[ -d "${PROJECT_ROOT}/wp-content/languages" ]]; then
  cp -a "${PROJECT_ROOT}/wp-content/languages" "${ARCHIVE_DIR}/wp-content/" 2>/dev/null || true
fi

# Preserve mu-plugins
if [[ -d "${PROJECT_ROOT}/wp-content/mu-plugins" ]]; then
  cp -a "${PROJECT_ROOT}/wp-content/mu-plugins" "${ARCHIVE_DIR}/wp-content/" 2>/dev/null || true
fi

# Copy essential PHP files
echo "[INFO] Copying core PHP files..."
cp -a "${PROJECT_ROOT}/wp-content" "${ARCHIVE_DIR}/" 2>/dev/null || true

# Create archive manifest
cat > "${ARCHIVE_DIR}/ARCHIVE_MANIFEST.md" <<EOF
# WordPress Legacy Archive

Archived: $(date -Iseconds)
Migration status: COMPLETE

## Contents

- \`dumps/\` — Database backups (SQL dumps)
- \`config-backup/\` — wp-config.php (sanitized + original)
- \`wp-content/uploads/\` — Complete media library backup
- \`wp-content/themes/\` — Theme files
- \`wp-content/plugins/\` — Plugin files

## Preserved

- All text content migrated to Hugo Markdown in \`site/content/\`
- All images extracted to \`site/static/images/wp-content/\`
- URL redirects generated in \`migration/redirects.caddy\`

## To restore WordPress temporarily

See \`scripts/rollback.sh\` — option 2 (restore WordPress backup on VPS).
EOF

echo "[INFO] Archive complete at ${ARCHIVE_DIR}"
echo "[INFO] Manifest written to ${ARCHIVE_DIR}/ARCHIVE_MANIFEST.md"
