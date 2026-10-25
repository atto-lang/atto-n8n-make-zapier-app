#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
cargo run --quiet --locked --manifest-path dependencies/api-docs/rust/Cargo.toml --bin api-docs-check -- rpc-contract-bundle --map "$root/contracts/live.route-map.json" --out "$root/generated/api" --check
node dependencies/tjsv/bin/typespec-json-schema-validator.mjs check --typespec="$root/contracts/main.tsp" --schema="$root/contracts/authored.schema.json" --instances="$root/contracts/instances" --format-assertion=true --report="$root/generated/schema-parity.json"
./scripts/tool routes
