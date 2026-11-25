# Current Atto policy migration candidate

The pure workflow domain remains one authoritative implementation in
`src/domain.ores` until the historic dependency stack is migrated. The new
admission runner projects it into an isolated `domain.atto` with canonical
`define pub module`, exercises explicit `copy!`, `eq`, an explicit `.atto`
module import, and `pub fnc main` against current compiler main pinned at
`b02efee4c036557278284ca444655e19cd0adc64` (tree `018f14281cb7af30c862c0dd25e1edc364148ca0`).
The 20 assertions cover transition, retry, kind and effect fencing,
including generation mismatch, cancellation, duplicate, checkpoint durability,
and both ends of signed sequence arithmetic. Exact stdout is required.

This is an unexecuted migration candidate. It neither upgrades the legacy
HTTP, ORM, generated route, and SSR dependencies nor asserts database,
compiler-backend parity, or production readiness. Keep their legacy source
extensions and compiler lock intact until the whole dependency/guest suite runs.
