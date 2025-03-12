#!/usr/bin/env bash

# Exit on error
set -e

echo "Stopping all Docker Compose services in subdirectories..."

# Find all directories
for dir in ./*/; do
    if [ -d "$dir" ]; then
        # Check if docker-compose file exists (either .yml or .yaml extension)
        if [ -f "${dir}docker-compose.yml" ] || [ -f "${dir}docker-compose.yaml" ] || [ -f "${dir}compose.yml" ] || [ -f "${dir}compose.yaml" ]; then
            echo "Found Docker Compose file in ${dir}, stopping services..."
            (cd "$dir" && docker compose down)
        fi
    fi
done

echo "All Docker Compose services have been stopped."
