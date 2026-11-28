-- Forward-only guards for durable identity, terminal state and deduplication.
-- These reject unsafe writes even before the workflow runtime is enabled.
-- Privileged migration roles can disable triggers; production roles must not
-- own the tables or hold DDL / BYPASSRLS privileges.

-- A terminal run must retain its completion receipt and final state.
-- A no-op status update used to pass the status-transition trigger while
-- allowing finished_at to be rewritten after completion.
ALTER TABLE runs ADD CONSTRAINT runs_finish_not_before_create
  CHECK (finished_at IS NULL OR finished_at >= created_at);

CREATE FUNCTION ores_run_terminal_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status IN ('succeeded','failed','cancelled') THEN
    RAISE EXCEPTION 'terminal run is immutable';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER run_terminal_guard
  BEFORE UPDATE ON runs
  FOR EACH ROW EXECUTE FUNCTION ores_run_terminal_guard();

-- Step attempts are independently auditable execution records. Retrying
-- creates a NEW attempt number; it must not rewrite an old attempt's identity
-- or resurrect a terminal attempt.
CREATE FUNCTION ores_step_attempt_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'queued' THEN
      RAISE EXCEPTION 'step attempt must start queued';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.workspace_id IS DISTINCT FROM OLD.workspace_id
     OR NEW.id IS DISTINCT FROM OLD.id
     OR NEW.run_id IS DISTINCT FROM OLD.run_id
     OR NEW.node_id IS DISTINCT FROM OLD.node_id
     OR NEW.item_key IS DISTINCT FROM OLD.item_key
     OR NEW.attempt IS DISTINCT FROM OLD.attempt THEN
    RAISE EXCEPTION 'step attempt identity is immutable';
  END IF;
  IF OLD.status IN ('succeeded','failed','cancelled') THEN
    RAISE EXCEPTION 'terminal step attempt is immutable';
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status AND NOT (
    (OLD.status = 'queued' AND NEW.status IN ('running','cancelled')) OR
    (OLD.status = 'running' AND NEW.status IN ('waiting','succeeded','failed','cancelled')) OR
    (OLD.status = 'waiting' AND NEW.status IN ('queued','cancelled'))
  ) THEN
    RAISE EXCEPTION 'invalid step attempt transition: % -> %', OLD.status, NEW.status;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER step_attempt_guard
  BEFORE INSERT OR UPDATE ON step_attempts
  FOR EACH ROW EXECUTE FUNCTION ores_step_attempt_guard();

-- A deduplication key must never be freed by deleting a received event;
-- otherwise a repeated webhook/poll response can be admitted as new work.
-- Retention/erasure will need a separate, explicitly reviewed protocol.
CREATE FUNCTION ores_trigger_event_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'trigger event identity is immutable';
END;
$$;
CREATE TRIGGER trigger_event_immutable
  BEFORE UPDATE OR DELETE ON trigger_events
  FOR EACH ROW EXECUTE FUNCTION ores_trigger_event_immutable();

-- Delivery is a one-way receipt. An outbox row's destination, key, payload,
-- and run binding cannot be changed. A delivered receipt cannot be retracted,
-- and deleting a row cannot free the provider-effect deduplication key.
CREATE FUNCTION ores_outbox_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.delivered_at IS NOT NULL THEN
      RAISE EXCEPTION 'outbox message cannot start delivered';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'outbox deduplication record cannot be deleted';
  END IF;
  IF OLD.delivered_at IS NOT NULL THEN
    RAISE EXCEPTION 'delivered outbox record is immutable';
  END IF;
  IF NEW.workspace_id IS DISTINCT FROM OLD.workspace_id
     OR NEW.id IS DISTINCT FROM OLD.id
     OR NEW.run_id IS DISTINCT FROM OLD.run_id
     OR NEW.destination IS DISTINCT FROM OLD.destination
     OR NEW.effect_key IS DISTINCT FROM OLD.effect_key
     OR NEW.payload_ref IS DISTINCT FROM OLD.payload_ref THEN
    RAISE EXCEPTION 'outbox effect identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER outbox_guard
  BEFORE INSERT OR UPDATE OR DELETE ON outbox
  FOR EACH ROW EXECUTE FUNCTION ores_outbox_guard();
