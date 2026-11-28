CREATE TABLE "workspaces" (
  "id" uuid NOT NULL,
  "name" text NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (id),
  CHECK (length(name) BETWEEN 1 AND 128)
);
CREATE TABLE "users" (
  "id" uuid NOT NULL,
  "subject" text NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (subject)
);
CREATE TABLE "memberships" (
  "workspace_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "role" text NOT NULL,
  PRIMARY KEY (workspace_id, user_id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  CHECK (role IN ('owner','editor','operator','viewer'))
);
CREATE TABLE "workflows" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "name" text NOT NULL,
  "revision" integer NOT NULL,
  "archived" boolean NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  CHECK (length(name) BETWEEN 1 AND 128),
  CHECK (revision >= 1)
);
CREATE TABLE "workflow_versions" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "workflow_id" uuid NOT NULL,
  "number" integer NOT NULL,
  "graph" jsonb NOT NULL,
  "contract_sha256" text NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, workflow_id) REFERENCES workflows(workspace_id, id),
  UNIQUE (workspace_id, workflow_id, id),
  UNIQUE (workspace_id, workflow_id, number),
  CHECK (number >= 1),
  CHECK (jsonb_typeof(graph) = 'object'),
  CHECK (contract_sha256 ~ '^[0-9a-f]{64}$')
);
CREATE TABLE "publications" (
  "workspace_id" uuid NOT NULL,
  "workflow_id" uuid NOT NULL,
  "version_id" uuid NOT NULL,
  "published_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, workflow_id),
  FOREIGN KEY (workspace_id, workflow_id, version_id) REFERENCES workflow_versions(workspace_id, workflow_id, id)
);
CREATE TABLE "connector_versions" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "key" text NOT NULL,
  "version" text NOT NULL,
  "manifest" jsonb NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  UNIQUE (workspace_id, key, version),
  CHECK (jsonb_typeof(manifest) = 'object')
);
CREATE TABLE "credentials" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "connector_version_id" uuid NOT NULL,
  "name" text NOT NULL,
  "secret_ref" text NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, connector_version_id) REFERENCES connector_versions(workspace_id, id)
);
CREATE TABLE "triggers" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "workflow_id" uuid NOT NULL,
  "kind" text NOT NULL,
  "config" jsonb NOT NULL,
  "enabled" boolean NOT NULL,
  "cursor" jsonb,
  "next_fire_at" timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, workflow_id) REFERENCES workflows(workspace_id, id),
  CHECK (kind IN ('manual','webhook','schedule','poll'))
);
CREATE TABLE "trigger_events" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "trigger_id" uuid NOT NULL,
  "external_key" text NOT NULL,
  "payload_ref" text NOT NULL,
  "received_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, trigger_id) REFERENCES triggers(workspace_id, id),
  UNIQUE (workspace_id, trigger_id, external_key)
);
CREATE TABLE "runs" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "workflow_id" uuid NOT NULL,
  "version_id" uuid NOT NULL,
  "trigger_event_id" uuid,
  "idempotency_key" text NOT NULL,
  "status" text NOT NULL,
  "input" jsonb NOT NULL,
  "created_at" timestamptz NOT NULL,
  "finished_at" timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, workflow_id, version_id) REFERENCES workflow_versions(workspace_id, workflow_id, id),
  FOREIGN KEY (workspace_id, trigger_event_id) REFERENCES trigger_events(workspace_id, id),
  UNIQUE (workspace_id, workflow_id, idempotency_key),
  CHECK (status IN ('queued','running','waiting','succeeded','failed','cancelled')),
  CHECK ((status IN ('succeeded','failed','cancelled')) = (finished_at IS NOT NULL))
);
CREATE TABLE "step_attempts" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "node_id" text NOT NULL,
  "item_key" text NOT NULL,
  "attempt" integer NOT NULL,
  "status" text NOT NULL,
  "input_ref" text,
  "output_ref" text,
  "error_code" text,
  "started_at" timestamptz,
  "finished_at" timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  UNIQUE (workspace_id, run_id, node_id, item_key, attempt),
  CHECK (attempt BETWEEN 1 AND 32),
  CHECK (status IN ('queued','running','waiting','succeeded','failed','cancelled'))
);
CREATE TABLE "jobs" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "step_attempt_id" uuid,
  "available_at" timestamptz NOT NULL,
  "lease_owner" text,
  "lease_until" timestamptz,
  "fence" bigint NOT NULL,
  "done" boolean NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  FOREIGN KEY (workspace_id, step_attempt_id) REFERENCES step_attempts(workspace_id, id),
  CHECK (fence >= 0),
  CHECK ((lease_owner IS NULL) = (lease_until IS NULL))
);
CREATE TABLE "run_events" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "sequence" bigint NOT NULL,
  "kind" text NOT NULL,
  "data" jsonb NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  UNIQUE (workspace_id, run_id, sequence),
  CHECK (sequence > 0)
);
CREATE TABLE "approvals" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "node_id" text NOT NULL,
  "status" text NOT NULL,
  "requested_at" timestamptz NOT NULL,
  "decided_at" timestamptz,
  "decided_by" uuid,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  FOREIGN KEY (workspace_id, decided_by) REFERENCES memberships(workspace_id, user_id),
  UNIQUE (workspace_id, run_id, node_id),
  CHECK (status IN ('pending','approved','rejected','expired')),
  CHECK ((status = 'pending') = (decided_at IS NULL))
);
CREATE TABLE "artifacts" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "storage_ref" text NOT NULL,
  "sha256" text NOT NULL,
  "media_type" text NOT NULL,
  "bytes" bigint NOT NULL,
  "expires_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  CHECK (bytes >= 0),
  CHECK (sha256 ~ '^[0-9a-f]{64}$')
);
CREATE TABLE "document_extractions" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "artifact_id" uuid NOT NULL,
  "schema_sha256" text NOT NULL,
  "model_ref" text NOT NULL,
  "fields" jsonb NOT NULL,
  "provenance" jsonb NOT NULL,
  "review_status" text NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, artifact_id) REFERENCES artifacts(workspace_id, id),
  CHECK (review_status IN ('pending','accepted','rejected'))
);
CREATE TABLE "desktop_tasks" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "device_id" text NOT NULL,
  "action_manifest" jsonb NOT NULL,
  "approval_id" uuid NOT NULL,
  "status" text NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  FOREIGN KEY (workspace_id, approval_id) REFERENCES approvals(workspace_id, id),
  CHECK (status IN ('proposed','approved','running','succeeded','failed','cancelled'))
);
CREATE TABLE "sessions" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "token_hash" text NOT NULL,
  "expires_at" timestamptz NOT NULL,
  "revoked_at" timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, user_id) REFERENCES memberships(workspace_id, user_id),
  UNIQUE (token_hash)
);
CREATE TABLE "outbox" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "run_id" uuid NOT NULL,
  "destination" text NOT NULL,
  "effect_key" text NOT NULL,
  "payload_ref" text NOT NULL,
  "delivered_at" timestamptz,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, run_id) REFERENCES runs(workspace_id, id),
  UNIQUE (workspace_id, destination, effect_key)
);
CREATE TABLE "audit_events" (
  "workspace_id" uuid NOT NULL,
  "id" uuid NOT NULL,
  "user_id" uuid,
  "action" text NOT NULL,
  "resource_id" uuid NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY (workspace_id, id),
  FOREIGN KEY (workspace_id) REFERENCES workspaces(id),
  FOREIGN KEY (workspace_id, user_id) REFERENCES memberships(workspace_id, user_id)
);

