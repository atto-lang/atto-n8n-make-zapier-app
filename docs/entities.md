# Database entities

Source authority: `src/models.ores`; SQL is compiled output. Every workspace-owned relation uses composite workspace foreign keys.

| Table | Columns |
|---|---|
| workspaces | id: uuid, name: text, created_at: timestamptz |
| users | id: uuid, subject: text, created_at: timestamptz |
| memberships | workspace_id: uuid, user_id: uuid, role: text |
| workflows | workspace_id: uuid, id: uuid, name: text, revision: integer, archived: boolean, created_at: timestamptz |
| workflow_versions | workspace_id: uuid, id: uuid, workflow_id: uuid, number: integer, graph: jsonb, contract_sha256: text, created_at: timestamptz |
| publications | workspace_id: uuid, workflow_id: uuid, version_id: uuid, published_at: timestamptz |
| connector_versions | workspace_id: uuid, id: uuid, key: text, version: text, manifest: jsonb |
| credentials | workspace_id: uuid, id: uuid, connector_version_id: uuid, name: text, secret_ref: text, created_at: timestamptz |
| triggers | workspace_id: uuid, id: uuid, workflow_id: uuid, kind: text, config: jsonb, enabled: boolean, cursor: jsonb?, next_fire_at: timestamptz? |
| trigger_events | workspace_id: uuid, id: uuid, trigger_id: uuid, external_key: text, payload_ref: text, received_at: timestamptz |
| runs | workspace_id: uuid, id: uuid, workflow_id: uuid, version_id: uuid, trigger_event_id: uuid?, idempotency_key: text, status: text, input: jsonb, created_at: timestamptz, finished_at: timestamptz? |
| step_attempts | workspace_id: uuid, id: uuid, run_id: uuid, node_id: text, item_key: text, attempt: integer, status: text, input_ref: text?, output_ref: text?, error_code: text?, started_at: timestamptz?, finished_at: timestamptz? |
| jobs | workspace_id: uuid, id: uuid, run_id: uuid, step_attempt_id: uuid?, available_at: timestamptz, lease_owner: text?, lease_until: timestamptz?, fence: bigint, done: boolean |
| run_events | workspace_id: uuid, id: uuid, run_id: uuid, sequence: bigint, kind: text, data: jsonb, created_at: timestamptz |
| approvals | workspace_id: uuid, id: uuid, run_id: uuid, node_id: text, status: text, requested_at: timestamptz, decided_at: timestamptz?, decided_by: uuid? |
| artifacts | workspace_id: uuid, id: uuid, run_id: uuid, storage_ref: text, sha256: text, media_type: text, bytes: bigint, expires_at: timestamptz |
| document_extractions | workspace_id: uuid, id: uuid, artifact_id: uuid, schema_sha256: text, model_ref: text, fields: jsonb, provenance: jsonb, review_status: text |
| desktop_tasks | workspace_id: uuid, id: uuid, run_id: uuid, device_id: text, action_manifest: jsonb, approval_id: uuid, status: text |
| sessions | workspace_id: uuid, id: uuid, user_id: uuid, token_hash: text, expires_at: timestamptz, revoked_at: timestamptz? |
| outbox | workspace_id: uuid, id: uuid, run_id: uuid, destination: text, effect_key: text, payload_ref: text, delivered_at: timestamptz? |
| audit_events | workspace_id: uuid, id: uuid, user_id: uuid?, action: text, resource_id: uuid, created_at: timestamptz |
