# Validation evidence — 2026-10-25

Local source/compiler evidence, not a hosted CI pass. No GitHub Actions run was
started; the Actions-budget fallback was not needed.

* Compiler/runtime: clean Java source `87a52fa7af40d3541277764533f51850b4db22bd`,
  built locally with Maven and JDK 25 before the final checks.
* Spin `87d8123aa22febc3b3ee469a479242941064250c`,
  routing `6c5413221d29f790b691ab9c1ad17b3160aeac9d`,
  SSR `b87a9932a15ac65421cb55b0eb37b20fbad98480`.
  These are the app's tested compatibility combination; they differ from some
  libraries' original compiler/router pins. Bootstrap deliberately attaches
  the pinned app router under Spin's dependency path.
* ORM source `337fc5632db40649d529533f975c634a5e69bd51`: native plans fixture passes
  with hostile identifier/type cases, nullable/required columns, bound values.
* App native contracts execute successfully: state transitions, retry policy
  limits and capped backoff, identifier/type admission and parameterized plans.
* Rust tooling: four unit tests pass for migration-plan admission, ordering,
  unchanged snapshots, filename validation and incomplete export rejection.
* Real isolated PostgreSQL 17: migrations apply twice, checksum tampering is
  rejected, immutable versions reject updates, duplicate run keys fail,
  invalid/terminal run transitions fail, cross-workspace publications fail,
  and a non-superuser NOBYPASSRLS role cannot read/write another workspace.
* `api-docs` Rust `api-docs-check rpc-contract-bundle --check` verifies six
  implemented routes and their generated docs/language surfaces. Shared
  contract SHA-256:
  `e6652aebd9612e0aef08d4bf3817460fd3892f5ea6f3cf45cb81c41185d5ce15`.
* TJSV `2d3b187aec68477cff579f2f3a9275ea5ef62f88` compares nine independently
  authored TypeSpec/JSON Schema declarations: 189 differential probes agree;
  zero findings, divergences, or refusals. Includes recorded valid/invalid
  request examples and format assertions. Full receipt: generated/schema-parity.json.
* WIT parses with wit-parser 0.240.0. This establishes syntax only.
* HTTP smoke: fresh native server; SSR page, POST preview, pinned HTMX asset,
  development health JSON, explicit WS 501, unknown path 404, wrong method 405.
* Browser: loaded the styled page, clicked Preview execution, verified HTMX
  replaced the fragment with the Oreslang-rendered approval preview. This is
  deliberately not evidence of persisted execution or a real approval.

Not tested or implemented: native DB transport, worker contention/crash recovery,
connector side effects, session/WebSocket ownership, login/CSRF flows, Zorde,
real RPC operation round-trip, production deployment, or WIT runtime parity.
These are product prerequisites, not inferred passes from schema tests.

## Hardening addendum — 2026-10-30

PR head hardening adds a forward-only 0003 migration, cross-run foreign keys,
append-only event/audit triggers, immutable version deletion protection,
one-way approval decisions, constrained job fencing, and explicit workspace
scoping in the illustrative worker SQL. A new PostgreSQL-only Actions workflow
and disposable-DB SQL adversarial fixtures were added.

**Status: newly added checks have not yet been observed executing.** The
2026-10-25 local results above apply to the previous foundation snapshot and
must not be represented as passes for this hardening revision. The worker
SQL remains a contract, not a deployed/executed worker. Production readiness,
tenant role security, run claim contention, crash/reclaim, and driver support
remain open.
