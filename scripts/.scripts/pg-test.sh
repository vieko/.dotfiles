#!/usr/bin/env bash
# pg-test.sh: a throwaway local Postgres for opt-in DB integration tests.
#
# Usage: pg-test.sh up [--repo DIR] | down | status | env [--repo DIR]
#   up      initdb (if needed) and start Postgres on 127.0.0.1:${PG_TEST_PORT:-54329},
#           create one database per *_TEST_DATABASE_URL the repo's
#           *.integration.test.ts files read, and print their exports.
#   env     print the exports again (server must be up).
#   down    stop the server and delete its data directory.
#   status  report whether it is running.
#
# Use: eval "$(pg-test.sh up)"; pnpm --filter <pkg> exec vitest run <file>;
#      pg-test.sh down
#
# Why: in ~/dev/gtm these suites skip unless their env var points at a
# localhost database, and no CI job provides one, so they only run here.
# Trust auth, bound to 127.0.0.1 only; the data lives under
# ${PG_TEST_DIR:-$TMPDIR/pg-test} and holds nothing worth keeping.
# Binaries: PATH first, then Homebrew's keg-only postgresql@17/@16.
set -euo pipefail

PORT="${PG_TEST_PORT:-54329}"
TMP_ROOT="${TMPDIR:-/tmp}"
DIR="${PG_TEST_DIR:-${TMP_ROOT%/}/pg-test}"
DATA="$DIR/data"

find_bin() {
  local name="$1" candidate
  if command -v "$name" >/dev/null 2>&1 && [[ "$name" != pg_ctl || -x "$(dirname "$(command -v "$name")")/postgres" ]]; then
    command -v "$name"
    return
  fi
  for candidate in /opt/homebrew/opt/postgresql@17/bin /opt/homebrew/opt/postgresql@16/bin \
    /usr/local/opt/postgresql@17/bin /usr/lib/postgresql/17/bin /usr/pgsql-17/bin /usr/bin; do
    if [[ -x "$candidate/$name" && -x "$candidate/postgres" ]]; then
      echo "$candidate/$name"
      return
    fi
  done
  echo "[ERROR] $name with a postgres server binary not found (brew install postgresql@17)" >&2
  exit 1
}

running() {
  [[ -f "$DATA/postmaster.pid" ]] && "$(find_bin pg_ctl)" -D "$DATA" status >/dev/null 2>&1
}

env_vars() {
  local repo="$1"
  [[ -d "$repo" ]] || { echo "[ERROR] not a directory: $repo" >&2; exit 1; }
  (cd "$repo" && git ls-files '*.integration.test.ts' 2>/dev/null |
    xargs -r grep -ohE 'process\.env\.[A-Z0-9_]+_TEST_DATABASE_URL' 2>/dev/null |
    sed 's/process\.env\.//' | sort -u)
}

print_env() {
  local repo="$1" var db
  for var in $(env_vars "$repo"); do
    db="$(echo "$var" | tr '[:upper:]' '[:lower:]')"
    echo "export $var=postgres://postgres@127.0.0.1:$PORT/$db"
  done
}

create_dbs() {
  local repo="$1" var db psql
  psql="$(dirname "$(find_bin pg_ctl)")/psql"
  for var in $(env_vars "$repo"); do
    db="$(echo "$var" | tr '[:upper:]' '[:lower:]')"
    if ! "$psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -Atqc \
      "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
      "$psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -qc "CREATE DATABASE \"$db\"" >&2
    fi
  done
}

repo_arg() {
  local repo
  repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="$2"; shift 2 ;;
      *) echo "[ERROR] unknown option: $1" >&2; exit 2 ;;
    esac
  done
  echo "$repo"
}

cmd="${1:-status}"
[[ $# -gt 0 ]] && shift
case "$cmd" in
  up)
    repo="$(repo_arg "$@")"
    pg_ctl="$(find_bin pg_ctl)"
    if [[ ! -f "$DATA/PG_VERSION" ]]; then
      mkdir -p "$DIR"
      "$(dirname "$pg_ctl")/initdb" -D "$DATA" -U postgres -A trust >/dev/null
    fi
    if ! running; then
      "$pg_ctl" -D "$DATA" -l "$DIR/server.log" -w \
        -o "-p $PORT -k $DIR -c listen_addresses=127.0.0.1" start >/dev/null
    fi
    create_dbs "$repo"
    echo "[OK] pg-test up on 127.0.0.1:$PORT ($DATA)" >&2
    print_env "$repo"
    ;;
  env)
    running || { echo "[ERROR] pg-test is not running; run: pg-test.sh up" >&2; exit 1; }
    print_env "$(repo_arg "$@")"
    ;;
  down)
    if running; then "$(find_bin pg_ctl)" -D "$DATA" -m fast stop >/dev/null; fi
    rm -rf "$DIR"
    echo "[OK] pg-test down; removed $DIR" >&2
    ;;
  status)
    if running; then echo "[OK] running on 127.0.0.1:$PORT ($DATA)"; else echo "[INFO] not running"; exit 1; fi
    ;;
  *)
    sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
