#!/usr/bin/env bash
# ========================================
# VPS Setup Script — Hugo + Caddy on Debian/Ubuntu
# Run as root on moneymachine
# ========================================
set -euo pipefail

DOMAIN="sanpablodelacruz.com"
PRIMARY_DOMAIN="www.${DOMAIN}"
HUGO_VERSION="0.159.2"
DEPLOY_DIR="/var/www/${DOMAIN}"
LEGACY_DIR="/var/www/${DOMAIN}-wordpress"
SITE_USER="www-data"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

verify_ssh() {
	log "Verifying SSH connectivity..."

	# If we're running this script over SSH, SSH clearly works.
	if [[ -n "${SSH_CONNECTION:-}" ]]; then
		log "SSH session confirmed (SSH_CONNECTION is set)."
		return 0
	fi

	# Try to detect sshd port multiple ways (Tailscale, non-standard ports, etc.)
	local ssh_listening=false

	if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -qE ':22\s|sshd'; then
		ssh_listening=true
	elif command -v netstat >/dev/null 2>&1 && netstat -tlnp 2>/dev/null | grep -qE ':22\s|sshd'; then
		ssh_listening=true
	elif systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
		ssh_listening=true
	elif pgrep -x sshd >/dev/null 2>&1; then
		ssh_listening=true
	fi

	if [[ "$ssh_listening" == "false" ]]; then
		warn "Could not detect sshd port with ss/netstat, but you are connected via SSH."
		warn "If this is a Tailscale or non-standard setup, this is expected."
		read -r -p "Continue anyway? [y/N] " confirm
		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			error "Aborted by user."
			exit 1
		fi
	else
		log "SSH service confirmed active."
	fi
}

# ========================================
# PRE-FLIGHT CHECKS
# ========================================
log "Starting VPS setup for ${DOMAIN}"
verify_ssh

if [[ "$EUID" -ne 0 ]]; then
	error "Must run as root"
	exit 1
fi

# ========================================
# SYSTEM UPDATE & DEPENDENCIES
# ========================================
log "Updating package lists..."
apt-get update -qq

log "Installing dependencies (curl, debian-keyring, ufw, iproute2)..."
apt-get install -y -qq curl debian-keyring ufw rsync iproute2

# ========================================
# FIREWALL — EXPLICITLY PRESERVE SSH
# ========================================
log "Configuring UFW firewall..."

# Reset to known state but NEVER disable
ufw --force reset || true
ufw default deny incoming
ufw default allow outgoing

# CRITICAL: Allow SSH before enabling
ufw allow 22/tcp comment 'SSH - NEVER DISABLE'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Enable firewall
ufw --force enable
log "UFW status:"
ufw status verbose

verify_ssh

# ========================================
# INSTALL HUGO
# ========================================
log "Installing Hugo v${HUGO_VERSION}..."

# Detect architecture for correct binary
ARCH=$(uname -m)
case "$ARCH" in
x86_64) HUGO_ARCH="linux-amd64" ;;
aarch64) HUGO_ARCH="linux-arm64" ;;
armv7l) HUGO_ARCH="linux-arm" ;;
*)
	error "Unsupported architecture: $ARCH"
	exit 1
	;;
esac

log "Detected architecture: $ARCH -> Hugo $HUGO_ARCH"

HUGO_TAR="hugo_extended_${HUGO_VERSION}_${HUGO_ARCH}.tar.gz"
HUGO_URL="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_TAR}"

cd /tmp
curl -sL "${HUGO_URL}" -o "${HUGO_TAR}"
tar -xzf "${HUGO_TAR}" hugo
mv hugo /usr/local/bin/hugo
chmod +x /usr/local/bin/hugo
rm -f "${HUGO_TAR}"
hugo version

# ========================================
# INSTALL CADDY
# ========================================
log "Installing Caddy..."
apt-get install -y -qq apt-transport-https ca-certificates gnupg

# Add Caddy repo
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

apt-get update -qq
apt-get install -y -qq caddy

# Verify Caddy
caddy version

# ========================================
# CREATE DEPLOY DIRECTORIES
# ========================================
log "Creating deploy directories..."
mkdir -p "${DEPLOY_DIR}"
mkdir -p "${LEGACY_DIR}"
chown -R "${SITE_USER}:${SITE_USER}" "${DEPLOY_DIR}"
chown -R "${SITE_USER}:${SITE_USER}" "${LEGACY_DIR}"

# ========================================
# CADDY CONFIGURATION
# ========================================
log "Writing Caddyfile..."
cat >/etc/caddy/Caddyfile <<CADDYEOF
${PRIMARY_DOMAIN} {
    root * ${DEPLOY_DIR}
    file_server
    encode gzip zstd

    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
        Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; script-src 'self'; font-src 'self';"
    }

    # WordPress legacy redirects (will be updated post-migration)
    @wpadmin path /wp-admin* /wp-login.php
    redir @wpadmin / permanent

    try_files {path} {path}/ =404

    # Custom error page
    handle_errors {
        rewrite * /404.html
        file_server
    }
}

${DOMAIN} {
    redir https://${PRIMARY_DOMAIN}{uri} permanent
}
CADDYEOF

# Validate and reload Caddy
log "Validating Caddy configuration..."
caddy validate --config /etc/caddy/Caddyfile

log "Enabling and starting Caddy..."
systemctl enable caddy
systemctl restart caddy

# ========================================
# CREATE ROLLBACK DIRECTORIES
# ========================================
mkdir -p "${DEPLOY_DIR}-previous"
mkdir -p "${DEPLOY_DIR}-wordpress-backup"
chown -R "${SITE_USER}:${SITE_USER}" "${DEPLOY_DIR}-previous"
chown -R "${SITE_USER}:${SITE_USER}" "${DEPLOY_DIR}-wordpress-backup"

# ========================================
# FINAL VERIFICATION
# ========================================
log "Running final connectivity checks..."
sleep 2

# Check Caddy is listening on 80/443
if command -v ss >/dev/null 2>&1; then
	if ss -tlnp | grep -q ':80 '; then
		log "Caddy listening on port 80 ✓"
	else
		warn "Caddy NOT listening on port 80"
	fi

	if ss -tlnp | grep -q ':443 '; then
		log "Caddy listening on port 443 ✓"
	else
		warn "Caddy NOT listening on port 443 (will activate after first request)"
	fi
else
	warn "ss command not found, skipping port verification"
fi

verify_ssh

log "========================================"
log "VPS setup complete!"
log "Domain: ${PRIMARY_DOMAIN}"
log "Deploy dir: ${DEPLOY_DIR}"
log "Caddy config: /etc/caddy/Caddyfile"
log "========================================"
log "Next steps:"
log "1. Ensure DNS A record points to this server"
log "2. Push code via GitHub Actions (deploy.yml)"
log "3. Caddy will aupto-provision HTTPS on first request"
