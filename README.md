# Ores Workflows

Native Oreslang workflow automation development. Research and the initial tested foundation are proposed separately for review.

## Repository ownership and migration (2026-11-08)

**Public language:** AttoLang; **current legacy home:** `ores-truffle-oreslang/oreslang-n8n-make-zapier-app`. Preserve old `.ores` files, `oreslang-*` repository, CLI, package and API names as compatibility surfaces pending a separately validated change.

- **Belongs in this repository:** AttoLang workflow/automation connector demonstrations and API bindings.
- **Does not belong here:** managed integration marketplace, credential escrow or commercial product operations.
- **Organization boundary:** [atto-lang](https://github.com/atto-lang) hosts portable language semantics, compiler targets, standard libraries, SDKs, tooling, conformance and examples. [atto-co](https://github.com/atto-co) separately owns managed cloud deployment, identity, billing, tenant hosting, registries and commercial services. A pre-existing similarly named `atto-*` repo is not assumed to be a transferred copy of this Git repository.
- **Initial migration proposal:** transfer this repository under the same name/ID to `atto-lang/oreslang-n8n-make-zapier-app` **only after** approval; no direct move from this old org into `atto-co` is currently authorized. Any future AttoCo product carve-out requires its own owner/security/consumer review.

**Maintainer migration checklist:** coordinate ownership and exact source head in [issue #26](https://github.com/ores-truffle-oreslang/.github/issues/26); follow the private [migration runbook draft #25](https://github.com/ores-truffle-oreslang/.github/pull/25). Inventory numeric repo ID and exact SHA/tree, PRs/releases, branch protections/rulesets, target visibility and permissions, Actions runners, secrets, webhooks, GitHub Apps, packages, Pages and consumer URLs; record source/target admin, independent security review and rollback owner. Never cross-org mirror private source without separate authorization. Perform only an authorized GitHub identity-preserving transfer; verify original ID/history/tree and restore controls afterward, update references incrementally and rerun **executed exact-head tests**. `steps=[]`/`null` is `NOT_EXECUTED`; host/static checks are not guest execution evidence or production safety proof.
