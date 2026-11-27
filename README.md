# Parroquia San Pablo de la Cruz — Static Site

[![Build and Deploy](https://github.com/juansanjose/church_website/actions/workflows/deploy.yml/badge.svg)](https://github.com/juansanjose/church_website/actions/workflows/deploy.yml)

Static Hugo site for [Parroquia San Pablo de la Cruz](https://www.sanpablodelacruz.com).

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
├── scripts/
│   ├── vps-setup.sh               # One-time VPS provisioning
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
- **CI/CD:** GitHub Actions build → self-hosted VPS deployment runner

## Editing Content

See [AGENT_PROTOCOL.md](AGENT_PROTOCOL.md) for the AI agent editing protocol.

## Deployment

- GitHub Actions builds every change to `main` and deploys it through a self-hosted runner on the VPS.
- Production files live in `/var/www/sanpablodelacruz.com`.
- Caddy serves `www.sanpablodelacruz.com` and redirects the apex domain to `www`.

## Rollback

```bash
# Revert to previous static deploy (< 60 seconds)
make rollback
```

## Carrera Familiar Solidaria

Preview the registration at `http://localhost:8080/carrera-familiar-solidaria/` with `make serve`.
The form submits to the Python service via Caddy. The service keeps reservations and notification
delivery state in `/var/lib/church-race/reservations.sqlite3`. Back up that database using SQLite's
backup command and apply the parish's data retention schedule. Parish staff track payments and
pickups in Gmail.

The form uses the supplied prices and ages: adults €15, children aged 3–14 €5, under-threes
free, and an optional Dorsal 0 donation for someone who will not participate. Payment details
are in `site/data/carrera.toml` and the supplied pickup schedule is on the thank-you page.
If the bank's Bizum donation flow has a concept field, the participant enters the reservation
reference there. A bank transfer supports the same reference, which is also in the staff email.
Review the privacy notice for the selected SMTP provider before launch.

Set the repository Actions secret `CHURCH_RACE_ENV` using the credentials of an authorized
SMTP sender that supports implicit TLS.
The recipient is always `sanpablodelacruz.madrid@gmail.com`.
On `moneymachine`, SMTP uses outbound TCP 465. The host's
`church-smtp-egress.service` preserves the public-interface blocks on outbound TCP
25 and 587 while the Netcup Mail block policy is detached.

```dotenv
RACE_SMTP_HOST=
RACE_SMTP_PORT=465
RACE_SMTP_USER=
RACE_SMTP_PASSWORD=
```

Set `RACE_SMTP_FROM` if the SMTP account uses a separate verified sending address.
Run the deploy workflow to start the service, and verify that a test notification from that
sender reaches the parish inbox. Configure Gmail filters for that sender:

- Reservations with an amount due have a subject containing `[Carrera]` without `Sin pago`. Apply
  `Carrera` and `Pendiente de pago`.
- Free reservations have a subject containing `[Carrera]` and `Sin pago`. Apply
  `Carrera` and `Listo para recoger`.

Staff replace `Pendiente de pago` with `Pagado` after matching the reference and amount
in the bank, then apply `Dorsales entregados` after pickup. The [Google Sheet
automation](scripts/carrera-sheet/README.md) mirrors these labels and imports each
reservation from its email. The registration and thank-you pages are published at
`/carrera-familiar-solidaria/` and `/carrera-familiar-solidaria/gracias/`.

## License

© Parroquia San Pablo de la Cruz. All rights reserved.
