> **AI agent instructions (organization-wide):** Before working on code, issues, or pull requests, read and follow the [organization `AGENTS.md`](https://github.com/ores-truffle-oreslang/.github/blob/main/AGENTS.md), including its **merge-first stealth-development policy**. Honor any repository-local `AGENTS.md`, explicit holds, and GitHub-enforced rules.

# Ores Workflows

## AttoLang migration and current documentation (2026-11-18)

**AttoLang (formerly Oreslang)** is the current language brand. This repository is `atto-lang/atto-n8n-make-zapier-app`; the historical location is `ores-truffle-oreslang/oreslang-n8n-make-zapier-app`. Migrated pull requests preserve historical provenance; do not infer identical repository IDs, Actions history, or feature status. Keep the historical example commands below for this checkout until independently validated replacements exist.

**Source of truth:** [atto-lang/atto-spec](https://github.com/atto-lang/atto-spec) defines current and proposed language semantics; [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance) provides portable positive/negative guest tests; [atto-common-source](https://github.com/atto-lang/atto-common-source) owns shared portable `.atto` code. New source aims for `snake_case` callables, `borrow!`/`take!`/`copy!`/`copy!!`/`share!`, [implicit borrowing](https://github.com/atto-lang/atto-spec/blob/main/language/implicit-argument-borrow-v1.md), [file/module constants with guarded one-time `os.read_env`](https://github.com/atto-lang/atto-spec/blob/main/language/file-module-const-v1.md), and [bitwise `<<<`/`>>>`/`ashr` distinct from stream `<<`/`>>`](https://github.com/atto-lang/atto-spec/blob/main/language/bitwise-and-stream-operators-v1.md). These are spec targets, not guaranteed executable features of this legacy repository.

Preserve legacy `.ores` paths, CLI/package/ABI names and wire formats where implemented. No Python support scripts, CI or tests; prefer Rust helper tooling. Document exact compiler SHA/tree, toolchain, executed guest positive/negative checks and unsupported/failed/not-executed outcomes. Host-only or zero-step CI cannot certify feature or backend parity.

Native Oreslang workflow automation development. Research and the initial tested foundation are proposed separately for review.

## Repository ownership and migration

- **Belongs in this repository:** AttoLang workflow/automation connector demonstrations and API bindings.
- **Does not belong here:** managed integration marketplace, credential escrow or commercial product operations.
- **Organization boundary:** [atto-lang](https://github.com/atto-lang) hosts portable language semantics, compiler targets, standard libraries, SDKs, tooling, conformance and examples. [atto-co](https://github.com/atto-co) separately owns managed cloud deployment, identity, billing, tenant hosting, registries and commercial services. A pre-existing similarly named `atto-*` repo is not assumed to be a transferred copy of this Git repository.

The historical transfer proposal is not an instruction to move this repository again. Any future transfer or managed-product carve-out needs separate owner authorization, exact source and destination identity verification, security and consumer review, and a rollback owner. Inventory repository ID, SHA/tree, PRs/releases, rulesets, runner settings, secrets metadata, webhooks, GitHub Apps, packages, Pages and consumer URLs; verify destination controls and executed exact-head tests after an authorized move. Never mirror private source without authorization and approved destination. Zero-step or host-only checks are not guest execution or production-safety evidence.
