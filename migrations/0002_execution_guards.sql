-- Workers complete a job only while holding its current fence. The update and
-- run/step events must commit together; see contracts/worker.sql.
CREATE INDEX jobs_ready ON jobs (available_at) WHERE NOT done;
CREATE INDEX runs_by_workflow ON runs (workspace_id, workflow_id, created_at DESC);
CREATE INDEX events_replay ON run_events (workspace_id, run_id, sequence);
CREATE INDEX artifacts_expiry ON artifacts (expires_at);
CREATE INDEX sessions_expiry ON sessions (expires_at);

CREATE FUNCTION ores_immutable_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'workflow versions are immutable; create a new version';
END;
$$;
CREATE TRIGGER workflow_versions_immutable BEFORE UPDATE ON workflow_versions
FOR EACH ROW EXECUTE FUNCTION ores_immutable_version();

CREATE FUNCTION ores_run_transition() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = OLD.status THEN RETURN NEW; END IF;
  IF (OLD.status = 'queued' AND NEW.status IN ('running','cancelled')) OR
     (OLD.status = 'running' AND NEW.status IN ('waiting','succeeded','failed','cancelled')) OR
     (OLD.status = 'waiting' AND NEW.status IN ('queued','cancelled')) THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'invalid run transition: % -> %', OLD.status, NEW.status;
END;
$$;
CREATE TRIGGER run_transition BEFORE UPDATE OF status ON runs
FOR EACH ROW EXECUTE FUNCTION ores_run_transition();

-- Authenticated request transactions must SET LOCAL app.workspace_id. A missing
-- setting sees no rows. Application roles must be non-superuser, NOBYPASSRLS.
-- Membership authorization precedes setting workspace_id; it is never client input.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['memberships','workflows','workflow_versions','publications',
    'connector_versions','credentials','triggers','trigger_events','runs','step_attempts',
    'jobs','run_events','approvals','artifacts','document_extractions','desktop_tasks',
    'sessions','outbox','audit_events']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY workspace_isolation ON %I USING (workspace_id = nullif(current_setting(''app.workspace_id'', true), '''')::uuid) WITH CHECK (workspace_id = nullif(current_setting(''app.workspace_id'', true), '''')::uuid)', t);
  END LOOP;
END;
$$;
