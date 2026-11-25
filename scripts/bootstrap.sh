#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/dependencies"
# Materialize immutable source pins. Existing directories must be clean checkouts
# at the requested commit; bootstrap never resets or overwrites local work.
for name in spin ssr http-routing pg api-docs tjsv; do
  repository="$(jq -r --arg name "$name" '.[$name].repository' "$root/dependencies.lock.json")"
  revision="$(jq -r --arg name "$name" '.[$name].commit' "$root/dependencies.lock.json")"
  tree="$(jq -r --arg name "$name" '.[$name].tree' "$root/dependencies.lock.json")"
  target="$root/dependencies/$name"
  if [[ ! -d "$target" ]]; then
    git clone --no-checkout "https://github.com/$repository.git" "$target"
    git -C "$target" fetch --no-tags origin "$revision"
    git -C "$target" checkout --detach "$revision"
  fi
  [[ "$(git -C "$target" rev-parse HEAD)" == "$revision" ]] || { echo "Dependency revision mismatch: $name" >&2; exit 69; }
  [[ "$(git -C "$target" rev-parse 'HEAD^{tree}')" == "$tree" ]] || { echo "Dependency tree mismatch: $name" >&2; exit 69; }
  [[ -z "$(git -C "$target" status --porcelain --untracked-files=no -- . ':(exclude)dependencies/http-routing')" ]] || { echo "Dependency is modified: $name" >&2; exit 69; }
done
router="$root/dependencies/spin/dependencies/http-routing"
if [[ ! -L "$router" ]]; then
  rmdir "$router"
  ln -s ../../http-routing "$router"
fi
(cd "$root/contracts" && npm ci --ignore-scripts --no-audit --no-fund)
(cd "$root/dependencies/tjsv" && npm ci --ignore-scripts --no-audit --no-fund && npm rebuild @oresoftware/f2e)
"$root/scripts/tool" embed-assets
