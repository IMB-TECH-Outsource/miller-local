# Miller server deploy

Only two files are needed on the server: `docker-compose.yml` and `.env`.
Everything else is pulled from Docker Hub (`imbtechdev/imb_hr:miller-backend-*`, `miller-frontend-*`)
or is a stock image (Postgres 17, Redis 7). The DB dumper is a `postgres:17-alpine` container with its script
inside `docker-compose.yml`.

```bash
cp .env.example .env      # set POSTGRES_PASSWORD, DJANGO_SECRET_KEY, DUMP_BOT_TOKEN, DUMP_CHAT_ID
docker login              # account with access to imbtechdev/imb_hr
docker compose up -d
```

Open `http://<server-ip>` (port `HTTP_PORT`). nginx in the frontend image proxies `/api`, `/admin`, `/static` to gunicorn.

| What | How |
|------|-----|
| Update | change `BACKEND_TAG` / `FRONTEND_TAG` in `.env`, then `docker compose pull && docker compose up -d` |
| Dump now | `docker compose exec dumper /dump.sh` |
| Dumps | `./backups/` (kept `DUMP_KEEP_DAYS`), also sent to Telegram |
| Restore | `gunzip -c backups/xxx.sql.gz \| docker compose exec -T postgres psql -U miller miller` |
| Logs | `docker compose logs -f backend` |

## Windows laptop (auto start on boot, no login)

Copy this folder to the laptop and run in PowerShell as Administrator:
`Set-ExecutionPolicy -Scope Process Bypass; .\windows\install.ps1`
It installs Docker Engine in WSL Ubuntu, copies `docker-compose.yml` + `.env` to `/opt/miller`,
starts the stack and registers a startup task.
