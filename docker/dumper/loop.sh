#!/bin/bash
set -uo pipefail

interval="${DUMP_INTERVAL_SECONDS:-86400}"

while true; do
  dump.sh || echo "Dump failed." >&2
  sleep "${interval}"
done
