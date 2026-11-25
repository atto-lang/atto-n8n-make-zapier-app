#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
compiler="${ATTO_COMPILER_DIR:?Set ATTO_COMPILER_DIR to the clean pinned current compiler checkout}"
expected=b02efee4c036557278284ca444655e19cd0adc64
tree=018f14281cb7af30c862c0dd25e1edc364148ca0
[[ "$(git -C "$compiler" rev-parse HEAD)" == "$expected" ]]
[[ "$(git -C "$compiler" rev-parse 'HEAD^{tree}')" == "$tree" ]]
[[ -z "$(git -C "$compiler" status --porcelain --untracked-files=no)" ]]
[[ -s "$compiler/target/classpath.txt" ]]
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# One canonical policy body: generate an isolated .atto module instead of
# creating ambiguous .atto/.ores imports or changing the historical server pin.
grep -qx 'define module domain as' "$root/src/domain.ores"
sed 's/^define module domain as$/define pub module domain as/' "$root/src/domain.ores" > "$tmp/domain.atto"
cp "$root/tests/atto/domain_policy.atto" "$tmp/main.atto"
run_guest() {
  java --enable-native-access=ALL-UNNAMED -Dpolyglot.engine.WarnInterpreterOnly=false \
    -cp "$compiler/target/classes:$(cat "$compiler/target/classpath.txt")" \
    dev.oreslang.launcher.OresMain "$1"
}
actual="$(run_guest "$tmp/main.atto")"
[[ "$actual" == '20' ]] || { printf 'Expected 20 passing assertions, got %s\n' "$actual" >&2; exit 1; }
printf 'Atto policy: 20 assertions passed; compiler=%s tree=%s\n' "$expected" "$tree"
