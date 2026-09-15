#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

docker compose pull -q
docker compose up -d
docker compose ps

# The site answering is the deploy's success condition, so a container that starts
# and serves nothing fails the job that called this.
curl -sf -o /dev/null http://localhost:8080/
