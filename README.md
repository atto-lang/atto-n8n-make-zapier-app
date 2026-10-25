# Ores Workflows

An Oreslang foundation for repeatable workflow automation inspired by n8n,
Make, Zapier, and Cortex. Native Spin/http-routing serves an oreslang-ssr
interface with self-hosted HTMX. Native model code compiles to PostgreSQL DDL.

**Status: tested development foundation, not a completed automation platform.**
The UI previews a fixed illustrative flow. It does not persist or execute a
workflow. `/ws` returns 501. Native PG transport, Zorde binding, durable workers,
authentication, and per-session WebSocket actors remain required.

Read [the research](docs/research.md), [architecture and delivery milestones](docs/architecture.md),
[entity inventory](docs/entities.md), and [requirement status](docs/requirements.md).

## Run locally

Requires JDK 25, Maven, Rust/Cargo, Node 22.18+, npm, jq, and GitHub access for
private pinned libraries. Build a **clean compiler checkout at the exact revision**
in `dependencies.lock.json`. The sibling `../oreslang-source.java` is the default;
set `ORESLANG_SOURCE_DIR` to use another checkout.

```sh
# In that compiler checkout:
mvn -q -DskipTests package dependency:build-classpath -Dmdep.outputFile=target/classpath.txt
# Back in this app:
./scripts/bootstrap.sh
./scripts/ores --platform=server --allow-net=127.0.0.1:8080 src/main.ores
```

Open [the development UI](http://127.0.0.1:8080). There is no React, browser app
framework, client-side workflow engine, runtime CDN, or production DB credential
in this repository.

## Verify

```sh
./scripts/test.sh
# Requires PostgreSQL 17 tools; creates and deletes its own temporary DB cluster:
PG_BIN=/path/to/postgresql/bin ./scripts/test-postgres.sh
```

`test.sh` checks native contracts, Rust migration tooling, native model/schema
snapshot parity, TypeSpec/JSON Schema parity, WIT syntax, and generated docs/
route/assets drift. It does not claim to test missing features. Native compiler
`--check` currently can print errors with exit status zero; tests also execute
the native contracts, and the HTTP smoke test verifies server startup.

## Migrate an explicitly selected development database

```sh
./scripts/tool check-models
./scripts/tool plan add_new_tables
PGHOST=/path/to/socket PGDATABASE=workflow_dev ./scripts/tool apply
```

New-table plans are candidates for review. Existing-table changes require
explicit SQL and a reviewed snapshot update. The migration runner checks
checksums and serializes apply with an advisory lock inside one transaction.
Never edit an applied migration. See architecture notes for forward repair,
backfill, and online migration limitations.

`contracts/live.route-map.json` owns implemented operation paths. Rust tooling
generates native Spin registration; api-docs emits the digest-bound docs/client
bundle in `generated/api`. `contracts/main.tsp` and `contracts/authored.schema.json`
are independent I/O peers checked with pinned TJSV. The WIT interface describes
a future worker boundary and is syntax-checked, not a deployed component.

[The ORM development PR](https://github.com/ores-truffle-oreslang/postgres-orm.ores/pull/1)
is pinned by commit, so its merge is not required to reproduce this snapshot.
