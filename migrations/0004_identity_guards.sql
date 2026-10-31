-- Forward-only protection for pinned execution identity and job leases.
-- No historical run may silently switch workflows, versions, inputs or keys.
CREATE FUNCTION ores_run_identity_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.workspace_id IS DISTINCT FROM OLD.workspace_id
     OR NEW.id IS DISTINCT FROM OLD.id
     OR NEW.workflow_id IS DISTINCT FROM OLD.workflow_id
     OR NEW.version_id IS DISTINCT FROM OLD.version_id
     OR NEW.trigger_event_id IS DISTINCT FROM OLD.trigger_event_id
     OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
     OR NEW.input IS DISTINCT FROM OLD.input
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'run identity and pinned input are immutable';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER run_identity_guard BEFORE UPDATE ON runs
  FOR EACH ROW EXECUTE FUNCTION ores_run_identity_guard();

-- Once a job is completed it cannot be resurrected, and an existing fence
-- cannot be rolled backward. Jobs always remain bound to their original run.
CREATE FUNCTION ores_job_identity_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.done THEN
    RAISE EXCEPTION 'completed job is immutable';
  END IF;
  IF NEW.workspace_id IS DISTINCT FROM OLD.workspace_id
     OR NEW.id IS DISTINCT FROM OLD.id
     OR NEW.run_id IS DISTINCT FROM OLD.run_id
     OR NEW.step_attempt_id IS DISTINCT FROM OLD.step_attempt_id
     OR NEW.fence < OLD.fence THEN
    RAISE EXCEPTION 'job identity or fence cannot be changed backward';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER job_identity_guard BEFORE UPDATE ON jobs
  FOR EACH ROW EXECUTE FUNCTION ores_job_identity_guard();

-- Pending approval identity is fixed; a response cannot be reassigned to
-- a different run, node or workspace before its decision is recorded.
CREATE FUNCTION ores_approval_identity_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.workspace_id IS DISTINCT FROM OLD.workspace_id
     OR NEW.id IS DISTINCT FROM OLD.id
     OR NEW.run_id IS DISTINCT FROM OLD.run_id
     OR NEW.node_id IS DISTINCT FROM OLD.node_id
     OR NEW.requested_at IS DISTINCT FROM OLD.requested_at THEN
    RAISE EXCEPTION 'approval identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER approval_identity_guard BEFORE UPDATE ON approvals
  FOR EACH ROW EXECUTE FUNCTION ores_approval_identity_guard();
