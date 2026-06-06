#!/usr/bin/env bash
# ========================================
# Rollback Script — Revert a bad deploy in < 60 seconds
# Run from local machine OR on VPS
# ========================================
set -euo pipefail

DOMAIN="sanpablodelacruz.com"
DEPLOY_DIR="/var/www/${DOMAIN}"
PREVIOUS_DIR="${DEPLOY_DIR}-previous"
WORDPRESS_BACKUP="/var/www/${DOMAIN}-wordpress-backup"
VPS_HOST="${VPS_HOST:-moneymachine}"
VPS_USER="${VPS_USER:-root}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[ROLLBACK]${NC} $1"; }
warn() { echo -e "${YELLOW}[ROLLBACK]${NC} $1"; }
error() { echo -e "${RED}[ROLLBACK]${NC} $1"; }

usage() {
  cat <<EOF
Usage: $0 [OPTION]

Options:
  previous    Restore the previous static deploy (default)
  wordpress   Restore the old WordPress site from backup
  status      Show current deploy status

Environment:
  VPS_HOST    Target VPS hostname (default: moneymachine)
  VPS_USER    SSH user (default: root)

Examples:
  VPS_HOST=moneymachine VPS_USER=root $0 previous
  $0 wordpress
EOF
  exit 1
}

verify_ssh() {
  log "Verifying SSH connectivity to ${VPS_USER}@${VPS_HOST}..."
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${VPS_USER}@${VPS_HOST}" "echo 'SSH_OK'" 2>/dev/null | grep -q "SSH_OK"; then
    error "SSH connection FAILED to ${VPS_USER}@${VPS_HOST}. ABORTING."
    exit 1
  fi
  log "SSH connectivity confirmed."
}

rollback_previous() {
  log "Rolling back to previous static deploy..."
  
  ssh "${VPS_USER}@${VPS_HOST}" bash -s <<'REMOTESCRIPT'
    set -euo pipefail
    DEPLOY_DIR="/var/www/sanpablodelacruz.com"
    PREVIOUS_DIR="${DEPLOY_DIR}-previous"
    
    if [[ ! -d "${PREVIOUS_DIR}" ]] || [[ -z "$(ls -A "${PREVIOUS_DIR}")" ]]; then
      echo "ERROR: No previous deploy found at ${PREVIOUS_DIR}"
      exit 1
    fi
    
    # Swap current to broken, previous to current
    mv "${DEPLOY_DIR}" "${DEPLOY_DIR}-broken"
    mv "${PREVIOUS_DIR}" "${DEPLOY_DIR}"
    mv "${DEPLOY_DIR}-broken" "${PREVIOUS_DIR}"
    
    # Fix ownership
    chown -R www-data:www-data "${DEPLOY_DIR}"
    
    # Reload Caddy
    systemctl reload caddy
    
    echo "Rollback complete."
REMOTESCRIPT

  log "Verifying site is accessible..."
  sleep 2
  if curl -sf "https://${DOMAIN}/" > /dev/null 2>&1; then
    log "Site is responding on HTTPS ✓"
  else
    warn "Site not responding on HTTPS yet (may need a few seconds)"
  fi
  
  verify_ssh
  log "Rollback to previous deploy COMPLETE."
}

rollback_wordpress() {
  log "Restoring WordPress backup..."
  
  ssh "${VPS_USER}@${VPS_HOST}" bash -s <<'REMOTESCRIPT'
    set -euo pipefail
    DEPLOY_DIR="/var/www/sanpablodelacruz.com"
    WORDPRESS_DIR="${DEPLOY_DIR}-wordpress-backup"
    
    if [[ ! -d "${WORDPRESS_DIR}" ]] || [[ -z "$(ls -A "${WORDPRESS_DIR}")" ]]; then
      echo "ERROR: No WordPress backup found at ${WORDPRESS_DIR}"
      exit 1
    fi
    
    # Save current static to previous
    rm -rf "${DEPLOY_DIR}-previous"
    cp -a "${DEPLOY_DIR}" "${DEPLOY_DIR}-previous"
    
    # Restore WordPress
    rm -rf "${DEPLOY_DIR}"
    cp -a "${WORDPRESS_DIR}" "${DEPLOY_DIR}"
    
    # Fix ownership
    chown -R www-data:www-data "${DEPLOY_DIR}"
    
    # Note: PHP-FPM and database must also be running for WordPress to work
    echo "WordPress files restored."
    echo "IMPORTANT: Ensure PHP-FPM and MySQL/MariaDB are running:"
    echo "  systemctl start php8.2-fpm"
    echo "  systemctl start mariadb"
REMOTESCRIPT

  verify_ssh
  log "WordPress restore COMPLETE."
}

show_status() {
  ssh "${VPS_USER}@${VPS_HOST}" bash -s <<'REMOTESCRIPT'
    set -euo pipefail
    DEPLOY_DIR="/var/www/sanpablodelacruz.com"
    echo "=== Deploy Status ==="
    echo "Current deploy size: $(du -sh "${DEPLOY_DIR}" 2>/dev/null | cut -f1)"
    echo "Previous deploy: $([ -d "${DEPLOY_DIR}-previous" ] && echo 'EXISTS' || echo 'MISSING')"
    echo "WordPress backup: $([ -d "${DEPLOY_DIR}-wordpress-backup" ] && echo 'EXISTS' || echo 'MISSING')"
    echo ""
    echo "=== Caddy Status ==="
    systemctl is-active caddy || echo "Caddy: INACTIVE"
    echo ""
    echo "=== Recent Caddy Access ==="
    tail -n 3 /var/log/caddy/access.log 2>/dev/null || echo "No access log available"
REMOTESCRIPT
}

# Main
ACTION="${1:-previous}"

case "${ACTION}" in
  previous)
    verify_ssh
    rollback_previous
    ;;
  wordpress)
    verify_ssh
    rollback_wordpress
    ;;
  status)
    show_status
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    error "Unknown action: ${ACTION}"
    usage
    ;;
esac
