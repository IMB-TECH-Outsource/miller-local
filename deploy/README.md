# Miller server deploy

Runs the published images (`imbtechdev/imb_hr:miller-backend-*`, `miller-frontend-*`, `miller-dumper-*`)
with Postgres 17 and Redis. The app is served on port 80: nginx serves the frontend and proxies
`/api`, `/admin`, `/static` to gunicorn; uploaded images live in the `media` volume.

## Windows laptop (starts on boot, no login needed)

1. Copy this `deploy` folder to the laptop, e.g. `C:\miller\deploy`.
2. In PowerShell **as Administrator**: `Set-ExecutionPolicy -Scope Process Bypass; .\windows\install.ps1`
3. First run creates `.env` — fill `POSTGRES_PASSWORD`, `DJANGO_SECRET_KEY`, `DUMP_BOT_TOKEN`, `DUMP_CHAT_ID`, run again.
4. If WSL was just installed: reboot, open "Ubuntu 24.04" once to create a user, run the script again.

The script installs Docker Engine inside WSL Ubuntu (systemd), logs in to Docker Hub, starts the stack,
registers the "Miller Server" startup task, opens port 80 and disables sleep on AC power.

## Linux server

```bash
cp .env.example .env   # edit values
docker login
docker compose up -d
```

## Update to a new version

Change `BACKEND_TAG` / `FRONTEND_TAG` in `.env`, then `docker compose pull && docker compose up -d`.

## Restore a dump

```bash
gunzip -c backups/xxx.sql.gz | docker compose exec -T postgres psql -U miller miller
```
