#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

docker compose pull -q
docker compose up -d
docker compose ps

# The app answering is the deploy's success condition, so a container that starts
# and serves nothing fails the job that called this. Node listens a moment after
# `up -d` returns, hence the retries.
curl -sf --retry 10 --retry-all-errors --retry-delay 1 -o /dev/null \
  http://localhost:8081/api/health
