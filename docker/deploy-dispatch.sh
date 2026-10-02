#!/usr/bin/env bash
set -euo pipefail

# Forced command of the CI deploy key. That key can run `deploy <stack>` and
# nothing else, for any stack that ships an executable deploy.sh beside its
# compose file.

# Letter ranges follow the locale, which the SSH client can set (AcceptEnv LC_*):
# under en_US.UTF-8, [a-z] also matches é and ß. The C locale means ASCII only.
export LC_ALL=C

docker_dir="$(cd "$(dirname "$0")" && pwd)"
command="${SSH_ORIGINAL_COMMAND:-}"

# The name pattern keeps `..` and `/` out, so the path below stays in docker_dir.
pattern='^deploy ([a-z0-9-]+)$'
if [[ ! "$command" =~ $pattern ]]; then
  echo "refused: expected 'deploy <stack>', got '$command'" >&2
  exit 1
fi
stack="${BASH_REMATCH[1]}"
script="$docker_dir/$stack/deploy.sh"

if [[ ! -x "$script" ]]; then
  echo "refused: stack '$stack' has no executable deploy.sh" >&2
  exit 1
fi

exec "$script"
