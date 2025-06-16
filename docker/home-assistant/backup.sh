#!/usr/bin/env bash

set -euo pipefail

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Make sure the restic.env file exists
if [ ! -f "restic.env" ]; then
    echo "restic.env file not found"
    echo "Please create it and try again. It should contain both RESTIC_REPOSITORY and RESTIC_PASSWORD."
    exit 1
fi

# Load backup.env file if it exists
if [ -f "backup.env" ]; then
    set -a
    source backup.env
    set +a
fi

notify_webhook() {
    local url="$1"
    if [[ -n "$url" ]]; then
        curl -fsS --connect-timeout 100 --max-time 120 "$url" || echo "Webhook failed: $url"
    fi
}

# Stop the Home Assistant service
docker compose down

# Backup the Home Assistant data
docker run --rm \
    --hostname home-assistant \
    --env-file restic.env \
    --volume "$(pwd):/data" \
    restic/restic:latest \
    backup /data

BACKUP_RESULT=$?

# Notify of the result
if [ "$BACKUP_RESULT" -eq 0 ]; then
    notify_webhook "$BACKUP_SUCCESS_WEBHOOK_URL"
else
    notify_webhook "$BACKUP_FAILURE_WEBHOOK_URL"
fi

# Prune the old backups
docker run --rm \
    --hostname home-assistant \
    --env-file restic.env \
    --volume "$(pwd):/data" \
    restic/restic:latest \
    forget \
    --prune \
    --keep-last 10 \
    --keep-daily 4 \
    --keep-weekly 12 \
    --keep-monthly 12 \
    --keep-yearly 10

FORGET_RESULT=$?

# Notify of the result
if [ "$FORGET_RESULT" -eq 0 ]; then
    notify_webhook "$FORGET_SUCCESS_WEBHOOK_URL"
else
    notify_webhook "$FORGET_FAILURE_WEBHOOK_URL"
fi

# Check the status of the backup
docker run --rm \
    --hostname home-assistant \
    --env-file restic.env \
    restic/restic:latest \
    check --read-data-subset=10G

CHECK_RESULT=$?

# Notify of the result
if [ "$CHECK_RESULT" -eq 0 ]; then
    notify_webhook "$CHECK_SUCCESS_WEBHOOK_URL"
else
    notify_webhook "$CHECK_FAILURE_WEBHOOK_URL"
fi

# Start the Home Assistant service
docker compose up -d
