# Parroquia San Pablo de la Cruz — Agent Instructions

## Project Status: MIGRATED TO STATIC SITE

This project has been migrated from WordPress to a Hugo static site.

## Quick Commands

```bash
# Local development
make serve          # Hugo dev server at http://localhost:8080
make build          # Build production site
make migrate        # Re-run WordPress → Hugo migration

# Deployment (automated via GitHub Actions)
git push origin main

# Rollback (if deploy breaks)
make rollback
```

## Architecture

- **Static Generator:** Hugo (v0.159.2, extended)
- **Web Server:** Caddy (automatic HTTPS)
- **Hosting:** VPS at `root@moneymachine`
- **CI/CD:** GitHub Actions build → self-hosted VPS deployment runner

## Content Editing

See `AGENT_PROTOCOL.md` for the complete AI agent editing protocol.

Key rules:
- Edit only in `site/content/` and `site/static/images/`
- Run `hugo --minify` before committing
- Use root-relative image paths: `/images/section/file.jpg`
- Follow front matter conventions

## Safety Rules

- [x] ALWAYS work on local environment (`make serve`)
- [x] NEVER touch live site directly (use GitHub Actions)
- [x] Test everything locally first
- [x] Run `hugo --minify` and verify 0 errors before commit
- [x] BACKUP before major changes via `make archive`
- [x] ALWAYS commit and push completed changes to `origin/main`

## Legacy WordPress

The old WordPress code is archived in `archive/legacy-wordpress/`.
Database dumps, uploads, and sanitized wp-config.php are preserved.

To temporarily restore WordPress:
```bash
VPS_HOST=moneymachine VPS_USER=root scripts/rollback.sh wordpress
```

## Repository Structure

```
church_website/
├── .github/workflows/deploy.yml    # CI/CD pipeline
├── archive/legacy-wordpress/       # Archived PHP/WordPress
├── migration/
│   ├── scripts/wordpress_to_hugo.py
│   └── redirects.caddy             # WP → Static redirects
├── scripts/
│   ├── vps-setup.sh                # VPS one-time setup
│   ├── archive-wordpress.sh
│   └── rollback.sh
├── site/                           # Hugo site
│   ├── content/                    # Markdown pages & posts
│   ├── layouts/                    # HTML templates
│   ├── static/images/              # Images
│   └── hugo.toml                   # Site config
├── Caddyfile                       # Caddy server config
├── Makefile
├── README.md
└── AGENT_PROTOCOL.md               # AI editing rules
```

## Theme: San Pablo

Custom minimal theme in `site/themes/sanpablo/`:
- Clean, accessible design
- Mobile-first responsive CSS
- Church-appropriate color palette (deep green, gold, warm white)
- Spanish language throughout

## Contact / Parameters

Site parameters in `site/hugo.toml`:
- Phone: 91 300 29 81
- Mobile: 628 223 783
- Additional mobile: 607 883 119
- Email: sanpablodelacruz@gmail.com
- Address: Avenida de los Madroños, 40, 28043 Madrid
