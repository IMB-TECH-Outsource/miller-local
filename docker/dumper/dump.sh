#!/bin/bash
set -euo pipefail

project="${DUMP_PROJECT_NAME:-Miller}"
stamp="$(date +%Y-%m-%d_%H-%M)"
file="/backups/$(echo "${project}" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')_${stamp}.sql.gz"

pg_dump --no-owner --no-privileges | gzip > "${file}"
size_bytes=$(stat -c %s "${file}")
echo "Dump created: ${file} (${size_bytes} bytes)"

if [ -z "${DUMP_BOT_TOKEN:-}" ] || [ -z "${DUMP_CHAT_ID:-}" ]; then
  echo "DUMP_BOT_TOKEN or DUMP_CHAT_ID is not set, Telegram upload skipped."
  exit 0
fi

if [ "${size_bytes}" -gt $((50 * 1024 * 1024)) ]; then
  echo "Dump is larger than Telegram's 50 MB limit, upload skipped." >&2
  exit 1
fi

caption="Proyekt: ${project}
📂 Ma'lumotlar bazasi dump fayli
🕒 $(date '+%d/%m/%Y %H:%M:%S')
📦 $(awk "BEGIN {printf \"%.2f\", ${size_bytes}/1048576}") MB
#$(echo "${project}" | tr ' ' '_')"

curl -sS --fail-with-body --max-time 300 \
  -F chat_id="${DUMP_CHAT_ID}" \
  -F caption="${caption}" \
  -F document=@"${file}" \
  "https://api.telegram.org/bot${DUMP_BOT_TOKEN}/sendDocument" > /dev/null

echo "Dump sent to Telegram chat ${DUMP_CHAT_ID}."

find /backups -name '*.sql.gz' -mtime +"${DUMP_KEEP_DAYS:-7}" -delete
