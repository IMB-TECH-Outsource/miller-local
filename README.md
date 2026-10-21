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

## Install on a Windows laptop (Wi-Fi access, auto start)

Copy this whole folder to the laptop (e.g. `C:\miller`) and double-click **`install.cmd`** (it asks for admin rights).

1. First run installs WSL. Restart Windows, open **Ubuntu 24.04** from the Start menu once, create a user, close it.
2. Double-click `install.cmd` again. It:
   - creates `.env` with random DB password and Django secret key,
   - installs Docker Engine inside WSL Ubuntu (no Docker Desktop needed),
   - asks for the Docker Hub login, pulls the images and starts Miller,
   - asks for your Windows password once to register the **"Miller Server"** startup task
     (Miller starts when the laptop is turned on, nobody has to log in),
   - opens the port in Windows Firewall (also on "Public" Wi-Fi), turns off sleep on AC and lid-close sleep.
3. At the end it prints the address, e.g. `http://192.168.1.25`. Anyone on the same Wi-Fi opens that address.

Reserve the laptop's IP in the Wi-Fi router (DHCP reservation) so the address stays the same.
Windows 11 22H2+ uses WSL mirrored networking; on Windows 10 `start.ps1` refreshes a port forward at every boot.

| File | Purpose |
|------|---------|
| `install.cmd` | double-click installer (runs `install.ps1` as admin) |
| `install.ps1` | one-time setup described above |
| `start.ps1` | run by the startup task: starts Docker + Miller, keeps WSL running |

Change settings later: edit `.env`, then in PowerShell `wsl -d Ubuntu-24.04 -u root -- sh -c "cp /mnt/c/miller/.env /opt/miller/.env && cd /opt/miller && docker compose up -d"`.
