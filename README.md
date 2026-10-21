# Miller

Runs Miller from ready images on Docker Hub. Nothing is built here.

```bash
cp .env.example .env      # set POSTGRES_PASSWORD, DJANGO_SECRET_KEY, DUMP_BOT_TOKEN, DUMP_CHAT_ID
docker login              # account with access to imbtechdev/imb_hr
docker compose up -d
```

Open `http://<server-ip>` (port `HTTP_PORT`).

| Service  | Image |
|----------|-------|
| backend  | `imbtechdev/imb_hr:miller-backend-${BACKEND_TAG}` |
| frontend | `imbtechdev/imb_hr:miller-frontend-${FRONTEND_TAG}` (nginx, proxies `/api` to backend) |
| postgres | `postgres:17` |
| redis    | `redis:7-alpine` |
| dumper   | `postgres:17-alpine`, dumps every `DUMP_INTERVAL_SECONDS` to `./backups` and Telegram |

| What | How |
|------|-----|
| Update | change `BACKEND_TAG` / `FRONTEND_TAG` in `.env`, then `docker compose pull && docker compose up -d` |
| Dump now | `docker compose exec dumper /dump.sh` |
| Restore | `gunzip -c backups/xxx.sql.gz \| docker compose exec -T postgres psql -U miller miller` |
| Logs | `docker compose logs -f backend` |
