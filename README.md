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

Preview the draft at `http://localhost:8080/carrera-familiar-solidaria/` with `make serve`.
The form submits to the Python service via Caddy. The service keeps reservations and notification
delivery state in `/var/lib/church-race/reservations.sqlite3`. Back up that database using SQLite's
backup command and apply the parish's data retention schedule. Parish staff track payments and
pickups in Gmail.

Before launch, confirm the category ages, the payment and pickup instructions, and the treatment
of `Dorsal fila cero`. The draft currently includes adults at €15, children aged 3–12 at €5,
and under-threes at €0. Review the privacy notice for the selected SMTP provider.

Set the repository Actions secret `CHURCH_RACE_ENV` to the following settings, using verified
values and the credentials of an authorized SMTP sender that supports implicit TLS.
The recipient is always `sanpablodelacruz@gmail.com`. Omit `RACE_BIZUM` if staff cannot
read the payment reference in the receiving bank's records.

```dotenv
RACE_SMTP_HOST=
RACE_SMTP_PORT=465
RACE_SMTP_USER=
RACE_SMTP_PASSWORD=
RACE_TRANSFER=
RACE_BIZUM=
RACE_PICKUP=
```

Set `RACE_SMTP_FROM` if the SMTP account uses a separate verified sending address.
Run the deploy workflow to start the service, and verify that a test notification from that
sender reaches the parish inbox. Configure Gmail filters for that sender:

- Paid reservations have a subject containing `[Carrera]` without `Sin pago`. Apply
  `Carrera` and `Pendiente de pago`.
- Free reservations have a subject containing `[Carrera]` and `Sin pago`. Apply
  `Carrera` and `Listo para recoger`.

Staff replace `Pendiente de pago` with `Pagado` after matching the reference and amount
in the bank, then apply `Dorsales entregados` after pickup. Once verified, remove
`draft: true` from the race page to publish it.

## License

© Parroquia San Pablo de la Cruz. All rights reserved.
