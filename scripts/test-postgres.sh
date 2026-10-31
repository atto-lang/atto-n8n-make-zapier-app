#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
pg_bin="${PG_BIN:-/opt/homebrew/opt/postgresql@17/bin}"
tmp="$(mktemp -d /tmp/ores-workflows-pg.XXXXXX)"
cleanup() { "$pg_bin/pg_ctl" -D "$tmp/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir "$tmp/socket"
"$pg_bin/initdb" -D "$tmp/data" --auth=trust --no-locale >/dev/null
"$pg_bin/pg_ctl" -D "$tmp/data" -l "$tmp/log" -o "-k $tmp/socket -h '' -p 55443" -w start >/dev/null
export PGHOST="$tmp/socket" PGPORT=55443 PGDATABASE=postgres
"$root/scripts/tool" apply
"$root/scripts/tool" apply
psql -X --set=ON_ERROR_STOP=1 --quiet -f "$root/tests/postgres.sql"
psql -X --set=ON_ERROR_STOP=1 --quiet -f "$root/tests/postgres-hardening.sql"
psql -X --set=ON_ERROR_STOP=1 --quiet -f "$root/tests/postgres-durable.sql"
psql -X --set=ON_ERROR_STOP=1 --quiet -f "$root/tests/postgres-tenant-auth.sql"
# Reject ledger tampering; the runner must fail before attempting any DDL.
psql -X --set=ON_ERROR_STOP=1 --quiet -c "UPDATE _ores_migrations SET sha256 = repeat('0',64) WHERE name='0001_initial.sql'"
if "$root/scripts/tool" apply > "$tmp/rejection.log" 2>&1; then
  echo 'Migration checksum mismatch was accepted' >&2
  exit 1
fi
rg --quiet 'Migration checksum mismatch' "$tmp/rejection.log"
echo 'Postgres migration and invariant tests passed'
