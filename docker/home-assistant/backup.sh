#!/usr/bin/env bash

set -euo pipefail

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Stop the Home Assistant service
docker compose down

# Make sure the restic.env file exists
if [ ! -f "restic.env" ]; then
    echo "restic.env file not found"
    echo "Please create it and try again. It should contain both RESTIC_REPOSITORY and RESTIC_PASSWORD."
    exit 1
fi

docker run --rm \
    --hostname home-assistant \
    --env-file restic.env \
    --volume "$(pwd):/data" \
    restic/restic:latest \
    backup /data

# Start the Home Assistant service
docker compose up -d
