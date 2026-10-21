#!/bin/bash
set -uo pipefail

until docker info >/dev/null 2>&1; do sleep 2; done
cd /opt/miller && docker compose up -d

exec sleep infinity
