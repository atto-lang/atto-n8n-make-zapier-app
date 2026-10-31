-- Forward-only integrity hardening for the schema in 0001/0002.
-- Existing rows must pass these validated constraints or deployment fails closed.
-- Do not edit migrations after application; use a new numbered migration.
ALTER TABLE step_attempts
  ADD CONSTRAINT step_attempts_run_identity UNIQUE (workspace_id, run_id, id);
ALTER TABLE approvals
  ADD CONSTRAINT approvals_run_identity UNIQUE (workspace_id, run_id, id);

-- Composite references in 0001 checked the workspace, but not that the
-- referenced attempt/approval belonged to the SAME run as its consumer.
ALTER TABLE jobs
  ADD CONSTRAINT jobs_attempt_same_run
  FOREIGN KEY (workspace_id, run_id, step_attempt_id)
  REFERENCES step_attempts (workspace_id, run_id, id);
ALTER TABLE desktop_tasks
  ADD CONSTRAINT desktop_tasks_approval_same_run
  FOREIGN KEY (workspace_id, run_id, approval_id)
  REFERENCES approvals (workspace_id, run_id, id);

ALTER TABLE jobs
  ADD CONSTRAINT jobs_done_unleased
  CHECK (NOT done OR (lease_owner IS NULL AND lease_until IS NULL)),
  ADD CONSTRAINT jobs_leases_have_fence
  CHECK (lease_owner IS NULL OR fence > 0);

-- 0002 protected historical versions against UPDATE, but not DELETE.
DROP TRIGGER workflow_versions_immutable ON workflow_versions;
CREATE TRIGGER workflow_versions_immutable
  BEFORE UPDATE OR DELETE ON workflow_versions
  FOR EACH ROW EXECUTE FUNCTION ores_immutable_version();

-- Historical run and audit records must not be rewritten after publication.
CREATE FUNCTION ores_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END;
$$;
CREATE TRIGGER run_events_append_only
  BEFORE UPDATE OR DELETE ON run_events
  FOR EACH ROW EXECUTE FUNCTION ores_append_only();
CREATE TRIGGER audit_events_append_only
  BEFORE UPDATE OR DELETE ON audit_events
  FOR EACH ROW EXECUTE FUNCTION ores_append_only();

-- An approval can be decided once. Revisions require a new approval record;
-- callers cannot flip a rejected/expired decision to an approved one.
ALTER TABLE approvals
  ADD CONSTRAINT approvals_decision_actor
  CHECK (
    (status = 'pending' AND decided_at IS NULL AND decided_by IS NULL)
    OR (status IN ('approved','rejected') AND decided_at IS NOT NULL AND decided_by IS NOT NULL)
    OR (status = 'expired' AND decided_at IS NOT NULL AND decided_by IS NULL)
  );

CREATE FUNCTION ores_approval_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pending' OR NEW.decided_at IS NOT NULL OR NEW.decided_by IS NOT NULL THEN
      RAISE EXCEPTION 'approval must start pending';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'approval decisions cannot be deleted';
  END IF;
  IF OLD.status <> 'pending' THEN
    RAISE EXCEPTION 'approval decision is immutable';
  END IF;
  IF NEW.status = 'pending' THEN
    IF NEW.decided_at IS NOT NULL OR NEW.decided_by IS NOT NULL THEN
      RAISE EXCEPTION 'pending approval cannot carry a decision';
    END IF;
  ELSIF NEW.status NOT IN ('approved','rejected','expired') THEN
    RAISE EXCEPTION 'invalid approval transition';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER approval_guard
  BEFORE INSERT OR UPDATE OR DELETE ON approvals
  FOR EACH ROW EXECUTE FUNCTION ores_approval_guard();
