-- Execute only against the complete 0001..0005 migration chain in
-- a disposable PostgreSQL database. Tests roll back all fixtures.
BEGIN;
INSERT INTO workspaces VALUES
 ('20000000-0000-4000-8000-000000000001','Durability guards',now());
INSERT INTO workflows VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000010','Sample',1,false,now());
INSERT INTO workflow_versions VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000020',
  '20000000-0000-4000-8000-000000000010',1,'{}',repeat('a',64),now());
INSERT INTO runs VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000030',
  '20000000-0000-4000-8000-000000000010','20000000-0000-4000-8000-000000000020',
  NULL,'run-1','queued','{}',now(),NULL),
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000031',
  '20000000-0000-4000-8000-000000000010','20000000-0000-4000-8000-000000000020',
  NULL,'run-2','queued','{}',now(),NULL);
INSERT INTO step_attempts VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000040',
  '20000000-0000-4000-8000-000000000030','node','item',1,'queued',NULL,NULL,NULL,NULL,NULL);

DO $$
BEGIN
  BEGIN
    UPDATE step_attempts SET run_id='20000000-0000-4000-8000-000000000031'
      WHERE id='20000000-0000-4000-8000-000000000040';
    RAISE EXCEPTION 'test failed: step moved to another run';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'step attempt identity is immutable' THEN RAISE; END IF;
  END;
  BEGIN
    UPDATE step_attempts SET status='succeeded'
      WHERE id='20000000-0000-4000-8000-000000000040';
    RAISE EXCEPTION 'test failed: step skipped running';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE 'invalid step attempt transition:%' THEN RAISE; END IF;
  END;
END;
$$;
UPDATE step_attempts SET status='running',started_at=now()
 WHERE id='20000000-0000-4000-8000-000000000040';
UPDATE step_attempts SET status='succeeded',finished_at=now()
 WHERE id='20000000-0000-4000-8000-000000000040';
DO $$
BEGIN
  BEGIN
    UPDATE step_attempts SET output_ref='tampered'
      WHERE id='20000000-0000-4000-8000-000000000040';
    RAISE EXCEPTION 'test failed: terminal step rewritten';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'terminal step attempt is immutable' THEN RAISE; END IF;
  END;
END;
$$;

UPDATE runs SET status='running'
 WHERE id='20000000-0000-4000-8000-000000000030';
UPDATE runs SET status='succeeded',finished_at=now()
 WHERE id='20000000-0000-4000-8000-000000000030';
DO $$
BEGIN
  BEGIN
    UPDATE runs SET finished_at=now()+interval '1 minute'
      WHERE id='20000000-0000-4000-8000-000000000030';
    RAISE EXCEPTION 'test failed: terminal run receipt rewritten';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'terminal run is immutable' THEN RAISE; END IF;
  END;
END;
$$;

INSERT INTO outbox VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000050',
  '20000000-0000-4000-8000-000000000031','test-provider','effect-1','sealed-ref',NULL);
DO $$
BEGIN
  BEGIN
    UPDATE outbox SET effect_key='effect-2'
      WHERE id='20000000-0000-4000-8000-000000000050';
    RAISE EXCEPTION 'test failed: outbox effect key overwritten';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'outbox effect identity is immutable' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM outbox WHERE id='20000000-0000-4000-8000-000000000050';
    RAISE EXCEPTION 'test failed: outbox dedupe key freed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'outbox deduplication record cannot be deleted' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO outbox VALUES
      ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000051',
       '20000000-0000-4000-8000-000000000031','test-provider','effect-2','sealed-ref',now());
    RAISE EXCEPTION 'test failed: outbox inserted delivered';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'outbox message cannot start delivered' THEN RAISE; END IF;
  END;
END;
$$;
UPDATE outbox SET delivered_at=now()
 WHERE id='20000000-0000-4000-8000-000000000050';
DO $$
BEGIN
  BEGIN
    UPDATE outbox SET delivered_at=NULL
      WHERE id='20000000-0000-4000-8000-000000000050';
    RAISE EXCEPTION 'test failed: delivered effect revoked';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'delivered outbox record is immutable' THEN RAISE; END IF;
  END;
END;
$$;

INSERT INTO triggers VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000060',
  '20000000-0000-4000-8000-000000000010','webhook','{}',true,NULL,NULL);
INSERT INTO trigger_events VALUES
 ('20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000061',
  '20000000-0000-4000-8000-000000000060','external-1','event-ref',now());
DO $$
BEGIN
  BEGIN
    UPDATE trigger_events SET external_key='external-2'
      WHERE id='20000000-0000-4000-8000-000000000061';
    RAISE EXCEPTION 'test failed: trigger dedupe key replaced';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'trigger event identity is immutable' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM trigger_events
      WHERE id='20000000-0000-4000-8000-000000000061';
    RAISE EXCEPTION 'test failed: trigger dedupe key deleted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'trigger event identity is immutable' THEN RAISE; END IF;
  END;
END;
$$;
ROLLBACK;
