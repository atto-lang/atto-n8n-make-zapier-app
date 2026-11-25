> **AI agent instructions (organization-wide):** Before working on code, issues, or pull requests, read and follow the [organization `AGENTS.md`](https://github.com/ores-truffle-oreslang/.github/blob/main/AGENTS.md), including its **merge-first stealth-development policy**. Honor any repository-local `AGENTS.md`, explicit holds, and GitHub-enforced rules.

# Ores Workflows

## AttoLang migration and current documentation (2026-11-18)

**AttoLang (formerly Oreslang)** is the current language brand. This repository is `atto-lang/atto-n8n-make-zapier-app`; the historical location is `ores-truffle-oreslang/oreslang-n8n-make-zapier-app`. Migrated pull requests preserve historical provenance; do not infer identical repository IDs, Actions history, or feature status. Keep the historical example commands below for this checkout until independently validated replacements exist.

**Source of truth:** [atto-lang/atto-spec](https://github.com/atto-lang/atto-spec) defines current and proposed language semantics; [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance) provides portable positive/negative guest tests; [atto-common-source](https://github.com/atto-lang/atto-common-source) owns shared portable `.atto` code. New source aims for `snake_case` callables, `borrow!`/`take!`/`copy!`/`copy!!`/`share!`, [implicit borrowing](https://github.com/atto-lang/atto-spec/blob/main/language/implicit-argument-borrow-v1.md), [file/module constants with guarded one-time `os.read_env`](https://github.com/atto-lang/atto-spec/blob/main/language/file-module-const-v1.md), and [bitwise `<<<`/`>>>`/`ashr` distinct from stream `<<`/`>>`](https://github.com/atto-lang/atto-spec/blob/main/language/bitwise-and-stream-operators-v1.md). These are spec targets, not guaranteed executable features of this legacy repository.

Preserve legacy `.ores` paths, CLI/package/ABI names and wire formats where implemented. No Python support scripts, CI or tests; prefer Rust helper tooling. Document exact compiler SHA/tree, toolchain, executed guest positive/negative checks and unsupported/failed/not-executed outcomes. Host-only or zero-step CI cannot certify feature or backend parity.

Native workflow automation development foundation. Historical validation is described below; the current Atto compiler and PostgreSQL execution must be verified separately.

## Repository ownership and migration

- **Belongs in this repository:** AttoLang workflow/automation connector demonstrations and API bindings.
- **Does not belong here:** managed integration marketplace, credential escrow or commercial product operations.
- **Organization boundary:** [atto-lang](https://github.com/atto-lang) hosts portable language semantics, compiler targets, standard libraries, SDKs, tooling, conformance and examples. [atto-co](https://github.com/atto-co) separately owns managed cloud deployment, identity, billing, tenant hosting, registries and commercial services. A pre-existing similarly named `atto-*` repo is not assumed to be a transferred copy of this Git repository.

The historical transfer proposal is not an instruction to move this repository again. Any future transfer or managed-product carve-out needs separate owner authorization, exact source and destination identity verification, security and consumer review, and a rollback owner. Inventory repository ID, SHA/tree, PRs/releases, rulesets, runner settings, secrets metadata, webhooks, GitHub Apps, packages, Pages and consumer URLs; verify destination controls and executed exact-head tests after an authorized move. Never mirror private source without authorization and approved destination. Zero-step or host-only checks are not guest execution or production-safety evidence.

## Development foundation

An Oreslang foundation for repeatable workflow automation inspired by n8n,
Make, Zapier, and Cortex. Native Spin/http-routing serves an oreslang-ssr
interface with self-hosted HTMX. Native model code compiles to PostgreSQL DDL.

**Status: development foundation, not a completed automation platform. Historical tests do not establish current-head validation.**
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
