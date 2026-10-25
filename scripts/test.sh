#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
cargo test --quiet --locked --manifest-path tooling/Cargo.toml
actual="$(./scripts/ores tests/domain.ores)"
[[ "$actual" == 'domain and pg contracts passed' ]]
./scripts/tool check-models
./scripts/tool check-wit
snapshot="$(mktemp -d /tmp/ores-workflows-generated.XXXXXX)"
trap 'rm -rf "$snapshot"' EXIT
cp -R generated/api "$snapshot/api"
cp src/main.ores "$snapshot/main.ores"
cp generated/assets.ores generated/routes.ores "$snapshot/"
./scripts/contracts.sh
./scripts/tool embed-assets
diff -r "$snapshot/api" generated/api
cmp "$snapshot/assets.ores" generated/assets.ores
cmp "$snapshot/routes.ores" generated/routes.ores
cmp "$snapshot/main.ores" src/main.ores
jq -e '.status == "passed" and .zeroUnexplainedFindings == true' generated/schema-parity.json >/dev/null
./scripts/http-smoke.sh
echo 'All implemented foundation checks passed'
