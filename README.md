# Parroquia San Pablo de la Cruz — Static Site

[![Build and Deploy](https://github.com/juansanjose/church_website/actions/workflows/deploy.yml/badge.svg)](https://github.com/juansanjose/church_website/actions/workflows/deploy.yml)

Static Hugo site for [Parroquia San Pablo de la Cruz](https://www.sanpablodelacruz.com), migrated from WordPress.

## Quickstart

```bash
# 1. Build locally
make build

# 2. Preview locally
make serve
# Open http://localhost:8080

# 3. Edit content (see AGENT_PROTOCOL.md)

# 4. Deploy (automated via GitHub Actions on push to main)
git add .
git commit -m "Update content"
git push origin main
```

## Repository Structure

```
.
├── .github/workflows/deploy.yml   # CI/CD: build + rsync to VPS
├── archive/legacy-wordpress/      # Archived WordPress code (post-migration)
├── migration/
│   ├── scripts/wordpress_to_hugo.py  # SQL → Markdown converter
│   └── redirects.caddy            # Caddy redirect rules
├── scripts/
│   ├── vps-setup.sh               # One-time VPS provisioning
│   ├── archive-wordpress.sh       # Archive legacy code
│   └── rollback.sh                # Revert bad deploys
├── site/                          # Hugo site source
│   ├── archetypes/                # Content templates
│   ├── assets/{css,js}/           # Source assets (processed by Hugo)
│   ├── content/                   # Markdown content
│   │   ├── _index.md              # Homepage
│   │   ├── la-parroquia/          # Section: La Parroquia
│   │   ├── celebraciones/         # Section: Celebraciones
│   │   ├── catequesis/            # Section: Catequesis
│   │   ├── horarios/              # Page: Horarios
│   │   ├── contactar/             # Page: Contactar
│   │   └── posts/                 # Blog posts
│   ├── layouts/                   # HTML templates
│   ├── static/                    # Static files (images, etc.)
│   └── hugo.toml                  # Site configuration
├── Caddyfile                      # Caddy web server config
└── Makefile
```

## Architecture

- **Generator:** Hugo (single binary, fast builds, mature ecosystem)
- **Server:** Caddy (automatic HTTPS, single binary, simple config)
- **Hosting:** Personal VPS at `root@moneymachine`
- **CI/CD:** GitHub Actions → rsync over SSH

## Editing Content

See [AGENT_PROTOCOL.md](AGENT_PROTOCOL.md) for the AI agent editing protocol.

## Migration Status

- ✅ WordPress content extracted to Markdown
- ✅ Images migrated to `site/static/images/wp-content/`
- ✅ URL redirects generated for Caddy
- ✅ Legacy WordPress code archived
- GitHub Actions builds every change to `main` and deploys it to the VPS.
- Production files live in `/var/www/sanpablodelacruz.com`.
- Caddy serves `www.sanpablodelacruz.com` and redirects the apex domain to `www`.

## Rollback

```bash
# Revert to previous static deploy (< 60 seconds)
make rollback

# Or restore WordPress temporarily
VPS_HOST=moneymachine VPS_USER=root scripts/rollback.sh wordpress
```

## License

© Parroquia San Pablo de la Cruz. All rights reserved.
