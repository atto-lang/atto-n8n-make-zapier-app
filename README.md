> **AI agent instructions (organization-wide):** Before working on code, issues, or pull requests, read and follow the [organization `AGENTS.md`](https://github.com/ores-truffle-oreslang/.github/blob/main/AGENTS.md), including its **merge-first stealth-development policy**. Honor any repository-local `AGENTS.md`, explicit holds, and GitHub-enforced rules.

# Ores Workflows

## AttoLang migration and current documentation (2026-11-18)

**AttoLang (formerly Oreslang)** is the current language brand. This `ores-truffle-oreslang/oreslang-n8n-make-zapier-app` checkout is a historical organization location; the corresponding new-home project is **no verified corresponding repository in atto-lang**. Do not assume a same-named project has identical Git commits, issues, PRs, Actions or feature status without checking exact history. Keep the historical example commands below for this checkout until independently validated replacements exist.

**Source of truth:** [atto-lang/atto-spec](https://github.com/atto-lang/atto-spec) defines current and proposed language semantics; [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance) provides portable positive/negative guest tests; [atto-common-source](https://github.com/atto-lang/atto-common-source) owns shared portable `.atto` code. New source aims for `snake_case` callables, `borrow!`/`take!`/`copy!`/`copy!!`/`share!`, [implicit borrowing](https://github.com/atto-lang/atto-spec/blob/main/language/implicit-argument-borrow-v1.md), [file/module constants with guarded one-time `os.read_env`](https://github.com/atto-lang/atto-spec/blob/main/language/file-module-const-v1.md), and [bitwise `<<<`/`>>>`/`ashr` distinct from stream `<<`/`>>`](https://github.com/atto-lang/atto-spec/blob/main/language/bitwise-and-stream-operators-v1.md). These are spec targets, not guaranteed executable features of this legacy repository.

Preserve legacy `.ores` paths, CLI/package/ABI names and wire formats where implemented. No Python support scripts, CI or tests; prefer Rust helper tooling. Document exact compiler SHA/tree, toolchain, executed guest positive/negative checks and unsupported/failed/not-executed outcomes. Host-only or zero-step CI cannot certify feature or backend parity.

Native Oreslang workflow automation development. Research and the initial tested foundation are proposed separately for review.
