#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

# The stack stays up during the backup, so the live SQLite file is being written
# to and is not safe to copy. SQLite's own backup API produces a consistent copy
# of an open database; restic.exclude keeps the live file out of the snapshot and
# takes this one instead.
#
# The copy is done in a single call rather than page by page: it blocks HA's
# writers for a few seconds, where the incremental form would restart itself
# every time a page changed underneath it.
mkdir -p appdata/home-assistant/db-snapshot

# With the container down there is no writer to be consistent with, and no
# python to call either. The database and its WAL are then a consistent set on
# their own: SQLite replays the WAL when the copy is next opened.
if [ "$(docker inspect -f '{{.State.Running}}' home_assistant 2>/dev/null)" != "true" ]; then
    echo "home_assistant is not running, taking a cold copy"
    cp -f appdata/home-assistant/home-assistant_v2.db appdata/home-assistant/db-snapshot/
    if [ -f appdata/home-assistant/home-assistant_v2.db-wal ]; then
        cp -f appdata/home-assistant/home-assistant_v2.db-wal appdata/home-assistant/db-snapshot/
    fi
    exit 0
fi

# A stale WAL from an earlier cold copy would be replayed into this one
rm -f appdata/home-assistant/db-snapshot/home-assistant_v2.db-wal

docker exec home_assistant python - <<'PY'
import sqlite3

source = sqlite3.connect("/config/home-assistant_v2.db")
target = sqlite3.connect("/config/db-snapshot/home-assistant_v2.db")

with target:
    source.backup(target)

# A copy that exists is not the same as a copy that restores.
result = target.execute("PRAGMA quick_check").fetchone()[0]
if result != "ok":
    raise SystemExit(f"quick_check on the snapshot returned: {result}")

target.close()
source.close()
PY
