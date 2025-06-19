#!/usr/bin/env bash

set -euo pipefail

notify_webhook() {
    local url="$1"
    if [[ -n "$url" ]]; then
        for i in {1..3}; do
            if curl -fsS --connect-timeout 10 --max-time 20 "$url"; then
                return 0
            fi
            sleep $((i * 2))
        done
        echo "Webhook failed after retries: $url"
    fi
}

stop_compose_stack() {
    local compose_file=""
    local was_running="false"

    # Find a docker-compose file
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$f" ]]; then
            compose_file="$f"
            break
        fi
    done

    if [[ -z "$compose_file" ]]; then
        echo "No Docker Compose file found in $(pwd)."
        return 0
    fi

    # Check if the stack is running (any container with the project label)
    if docker compose ps --services --filter "status=running" | grep -q .; then
        docker compose down
        was_running="true"
    fi

    # Save the state so you can restart later
    export LAST_COMPOSE_WAS_RUNNING="$was_running"
}

backup_folder() {
    local -r folder_path="$1"

    # Check if the path exists and is a directory
    if [ ! -d "$folder_path" ]; then
        echo "Error: '$folder_path' is not a directory or does not exist."
        return 1
    fi

    (
        set -euo pipefail

        cd "$folder_path"

        # Make sure the restic.env file exists
        if [ ! -f "restic.env" ]; then
            echo "restic.env file not found"
            echo "Please create it and try again. It should contain both RESTIC_REPOSITORY and RESTIC_PASSWORD and optionally RESTIC_HOST."
            exit 1
        fi
        if ! grep -q '^RESTIC_REPOSITORY=' restic.env || ! grep -q '^RESTIC_PASSWORD=' restic.env; then
            echo "restic.env is missing required variables"
            exit 1
        fi

        # Load backup.env file into the current shell if it exists
        if [ -f "backup.env" ]; then
            set -a
            source backup.env
            set +a
        fi

        # Pull the latest restic image
        docker pull restic/restic:latest

        stop_compose_stack

        echo "Starting restic backup..."
        if [ -f "restic.include" ]; then
            BACKUP_CMD=(backup --files-from=/data/restic.include)
        else
            BACKUP_CMD=(backup /data)
        fi

        # Add exclude file if present
        if [ -f "restic.exclude" ]; then
            BACKUP_CMD+=("--exclude-file=/data/restic.exclude")
        fi

        set +e
        # Backup
        docker run --rm \
            --env-file restic.env \
            --volume restic-cache:/root/.cache/restic \
            --volume "$(pwd):/data:ro" \
            restic/restic:latest \
            "${BACKUP_CMD[@]}"
        BACKUP_RESULT=$?

        if [[ -n "${LAST_COMPOSE_WAS_RUNNING:-}" && "$LAST_COMPOSE_WAS_RUNNING" == "true" ]]; then
            docker compose up -d
        fi

        # Notify of the result
        if [ "$BACKUP_RESULT" -eq 0 ]; then
            notify_webhook "$BACKUP_SUCCESS_WEBHOOK_URL"
        else
            notify_webhook "$BACKUP_FAILURE_WEBHOOK_URL"
        fi

        if [ "$BACKUP_RESULT" -ne 0 ]; then
            echo "Backup failed, skipping forget and check"
            exit 1
        fi

        # Prune the old backups
        docker run --rm \
            --env-file restic.env \
            --volume restic-cache:/root/.cache/restic \
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
            --env-file restic.env \
            --volume restic-cache:/root/.cache/restic \
            restic/restic:latest \
            check --read-data-subset=10G

        CHECK_RESULT=$?

        # Notify of the result
        if [ "$CHECK_RESULT" -eq 0 ]; then
            notify_webhook "$CHECK_SUCCESS_WEBHOOK_URL"
        else
            notify_webhook "$CHECK_FAILURE_WEBHOOK_URL"
        fi

        echo "Backup of '$folder_path' completed successfully."
    )
}
