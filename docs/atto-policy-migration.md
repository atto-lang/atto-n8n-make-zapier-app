# Current Atto policy migration candidate

The pure workflow domain remains one authoritative implementation in
`src/domain.ores` until the historic dependency stack is migrated. The new
admission runner projects it into an isolated `domain.atto` with compiler-admitted
`define module` and public members, exercises explicit `copy!`, `eq`, an explicit `.atto`
module import, and `pub fnc main` against current compiler main pinned at
`b02efee4c036557278284ca444655e19cd0adc64` (tree `018f14281cb7af30c862c0dd25e1edc364148ca0`).
The 20 assertions cover transition, retry, kind and effect fencing,
including generation mismatch, cancellation, duplicate, checkpoint durability,
and both ends of signed sequence arithmetic. Exact stdout is required.

The initial execution (run 45546596236) built the pinned compiler but rejected
`define pub module` at parse time: modules do not accept declaration modifiers.
That spec-target spelling is therefore explicitly unsupported by this compiler
revision; the candidate uses the admitted declaration instead. The revised
20-case guest has not yet passed. It neither upgrades the legacy
HTTP, ORM, generated route, and SSR dependencies nor asserts database,
compiler-backend parity, or production readiness. Keep their legacy source
extensions and compiler lock intact until the whole dependency/guest suite runs.
