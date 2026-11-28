# Workflow platform model research

Investigated 2026-10-25. Evidence levels matter: n8n publishes actual database
entities; Make and Zapier expose public resource and behavioral contracts;
Cortex publishes product architecture and privacy statements. No public source
reviewed establishes the private physical SQL schemas of Make, Zapier, or Cortex.
Their proposed table mappings below are our design inferences.

## n8n: verified entity model

The [database guide](https://docs.n8n.io/deploy/host-n8n/understand-the-architecture/understand-the-database.md)
identifies TypeORM as the query/migration layer and distinguishes workflow
metadata, execution data, execution metadata, credentials, sharing, projects,
users, variables, webhook registrations, workflow history, and migrations.
Execution payloads include the workflow at execution time. This supports an
important separation: editing a definition must not rewrite historical runs.

The [WorkflowEntity source](https://github.com/n8n-io/n8n/blob/master/packages/%40n8n/db/src/entities/workflow-entity.ts)
stores nodes and connections as JSON, alongside settings, static/pinned data,
version identity, a published-version reference, archive state, and project
organization through related entities. A workflow is a graph plus lifecycle
metadata, rather than one SQL table per integration or step type.

The [published PostgreSQL execution schema](https://github.com/n8n-io/n8n/blob/master/docs/generated/postgres-schema/public.execution_entity.md)
separates execution rows from payload data, metadata, annotations, and test-case
execution relations. Our choice is similarly to index small run rows and move
large step artifacts behind references. We additionally normalize step attempts
for leasing, retry inspection, and item-level idempotency. That is our design,
not a claim that n8n uses our tables.

## Make: verified public resources, inferred storage

The [scenario API](https://developers.make.com/api-documentation/api-reference/scenarios)
scopes scenario collections to teams or organizations and provides lifecycle,
activation and folder concepts. This implies that ownership/access boundaries
belong above individual module configurations. Our workspace/membership model
provides that boundary.

The [blueprint API](https://developers.make.com/api-documentation/api-reference/scenarios/blueprints)
exposes versioned draft/live blueprints. A flow contains module identifiers and
versions, parameter/mapping configuration, error routes, and designer metadata.
Blueprint history and scheduling are distinct concerns. Saving with a base
version allows concurrency conflict detection. We therefore propose immutable
workflow versions, a publication pointer, connector version pins, explicit
error handling, and optimistic revision checks. UI coordinates should remain
presentation metadata, without changing runtime scheduling semantics.

[Incomplete executions](https://developers.make.com/api-documentation/api-reference/incomplete-executions)
are retained failed executions that can be inspected and resolved. The API
exposes retry state, attempts, and scheduled retry information. We model retries
as additional step attempts and queue jobs; a failed run is not overwritten to
look like a fresh successful execution. Retaining failure inputs enables an
operator to resume deliberately. This does not establish Make's table names or
physical database engine.

## Zapier: verified deduplication, inferred storage

The [polling deduplication guide](https://docs.zapier.com/integrations/build/deduplication)
describes unique item IDs and remembering seen IDs so recurring polling does not
re-trigger already observed items. Integration identity and stable event identity
must therefore be separate from a run's correlation ID.

Our `trigger_events` unique key is `(workspace_id, trigger_id, external_key)`.
Polling cursor state lives on a trigger; a cursor alone cannot provide durable
deduplication. Event admission and run/job creation must be transactional. A
workflow-level idempotency key also protects manual and webhook requests.
Provider side effects require their own stable effect key; a DB uniqueness
constraint cannot make an arbitrary external API execute exactly once.

Credentials must be separate resources referenced by connector configurations.
We infer a need for connector versions, connection references, trigger config,
workflow steps, execution attempts, and usage records from the integration
product model. We do not assert Zapier's private ORM, database engine, table
names, or a normalized internal step schema.

## Cortex: desktop workspace and reviewed actions

[Cortex's FAQ](https://withcortex.ai/faq) describes local documents, document
reading/OCR, browser interactions, review of actions, shared workflows, and
team administration. Its [home page](https://withcortex.ai/) describes local
project folders and limited AI-request processing. These sources do not disclose
a backend schema or a public durable workflow engine comparable to n8n.

The useful product requirements are document artifacts, structured extraction,
source provenance, review state, device identity, and human decisions before
browser actions. We propose `artifacts`, `document_extractions`, `approvals`,
and `desktop_tasks` as separate records. A hosted Oreslang app cannot access a
user's local files simply by adding a database table. This requires a separately
installed, authenticated desktop agent with explicit file/application access.
Server-side Postgres also differs from Cortex's stated local project storage;
we must define our own retention and synchronization policy instead of copying
its privacy claims.

## Resulting design decisions

| Concern | Our choice | Reason |
|---|---|---|
| Workflow definitions | immutable JSONB graph versions | portable connector configuration, replay against the original definition |
| Publication | workspace/workflow → version reference | draft edits do not alter published work |
| Runs | indexed identity/state separate from payloads | efficient history and retention |
| Step attempts | node + item + attempt identity | retries and fan-out need distinct execution records |
| Scheduling | durable jobs with leases/fencing | process death must not lose work or allow stale completion |
| Triggers | config/cursor + deduplicated event inbox | repeated delivery is normal |
| Side effects | transactional outbox + provider idempotency | delivery is at least once |
| Live UI | session actor + replayable run events | reconnect independently of execution lifetime |
| Credentials | external secret references | graphs, logs, and exports never carry plaintext secrets |
| Documents | artifact refs + extraction provenance + approval | reviewable document-to-application workflows |
| Tenancy | composite foreign keys + forced RLS | prevent accidental cross-workspace references |

## What the bootstrap schema still needs

The initial 21 product tables make the principal relations concrete. The schema
is not a complete commercial platform. Before execution ships, add relational
consistency between a job and its step/run, append-only enforcement for audit/run
events, publication/graph semantic validation, version deletion policy, session
token hashing and lifecycle, per-step approval uniqueness for fan-out, encrypted
secret-provider rotation, quotas/usage ledgers, OAuth installation lifecycle,
connector permission scopes, schedules with timezone/DST policy, persisted
subworkflow/loop scopes, and artifact erasure/retention rules.

JSON Schema checks structural I/O; graph publication also needs unique node IDs,
valid ports and edges, bounded fan-out, cycle/loop policy, connector admission,
credential authorization, and schema compatibility. SQL alone cannot validate
those semantics. Initial WIT syntax validation likewise does not prove a compiled
Oreslang component ABI or WIT/JSON/TypeSpec runtime equivalence.
