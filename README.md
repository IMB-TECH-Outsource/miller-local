# Miller dev

One project to run the whole Miller stack locally: backend (Django), frontend (Vite),
Postgres, Redis and a database dumper that sends backups to Telegram.

Backend and frontend code is cloned from GitHub into `src/` and built with the Dockerfiles in `docker/`.

## Start

```bash
make init      # creates .env, clones both repos
make up        # git pull + docker pull + build + start
make superuser
```

| Service  | URL |
|----------|-----|
| frontend | http://localhost:3002 |
| backend  | http://localhost:8000/api/v1 |
| postgres | localhost:5433 (miller/miller) |

Code in `src/backend` and `src/frontend` is mounted into containers, so edits reload live.
`make pull` skips a repo that has local changes. Branches and repo URLs are in `.env`.

## Dumper

Every `DUMP_INTERVAL_SECONDS` (default 24h) the `dumper` service runs `pg_dump`, keeps the file in `backups/`
(`DUMP_KEEP_DAYS`) and sends it to Telegram. Set `DUMP_BOT_TOKEN` and `DUMP_CHAT_ID` in `.env`, then `docker compose up -d dumper`.

```bash
make dump                                   # dump now
make restore FILE=backups/xxx.sql.gz        # restore into local Postgres
```

## Other commands

`make down`, `make logs`, `make ps`, `make restart`, `make shell`
