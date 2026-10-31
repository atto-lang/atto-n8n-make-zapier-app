-- Execute after applying 0001..0003, as the migration owner in a
-- disposable test database. The transaction rolls back fixtures at the end.
BEGIN;
INSERT INTO workspaces VALUES
 ('10000000-0000-4000-8000-000000000001','Integrity tests',now());
INSERT INTO users VALUES
 ('10000000-0000-4000-8000-000000000002','test-user',now());
INSERT INTO memberships VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','operator');
INSERT INTO workflows VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','Review',1,false,now());
INSERT INTO workflow_versions VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000020','10000000-0000-4000-8000-000000000010',1,'{}',repeat('a',64),now()),
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000021','10000000-0000-4000-8000-000000000010',2,'{}',repeat('a',64),now());
INSERT INTO runs VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','10000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000020',NULL,'first','queued','{}',now(),NULL),
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000031','10000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000020',NULL,'second','queued','{}',now(),NULL);
INSERT INTO step_attempts VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000040','10000000-0000-4000-8000-000000000030','node','item',1,'queued',NULL,NULL,NULL,NULL,NULL);

DO $$
BEGIN
  BEGIN
    INSERT INTO jobs VALUES
      ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000050','10000000-0000-4000-8000-000000000031',
       '10000000-0000-4000-8000-000000000040',now(),NULL,NULL,0,false);
    RAISE EXCEPTION 'test failed: job accepted attempt from another run';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;

  BEGIN
    DELETE FROM workflow_versions WHERE id='10000000-0000-4000-8000-000000000021';
    RAISE EXCEPTION 'test failed: immutable version was deleted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'workflow versions are immutable; create a new version' THEN RAISE; END IF;
  END;
END;
$$;

INSERT INTO jobs VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000051','10000000-0000-4000-8000-000000000030',
  '10000000-0000-4000-8000-000000000040',now(),NULL,NULL,0,false);

DO $$
BEGIN
  BEGIN
    UPDATE jobs SET lease_owner='worker', lease_until=now() + interval '30 seconds'
      WHERE id='10000000-0000-4000-8000-000000000051';
    RAISE EXCEPTION 'test failed: lease without fence accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;

  BEGIN
    UPDATE jobs SET done=true, lease_owner='worker',
      lease_until=now() + interval '30 seconds',fence=1
      WHERE id='10000000-0000-4000-8000-000000000051';
    RAISE EXCEPTION 'test failed: completed job still leased';
  EXCEPTION WHEN check_violation THEN NULL; END;
END;
$$;

INSERT INTO approvals VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000080','10000000-0000-4000-8000-000000000030',
  'approval-node','pending',now(),NULL,NULL);
DO $$
BEGIN
  BEGIN
    INSERT INTO desktop_tasks VALUES
      ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000081','10000000-0000-4000-8000-000000000031',
       'device','{}','10000000-0000-4000-8000-000000000080','proposed');
    RAISE EXCEPTION 'test failed: desktop task accepted approval from another run';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;

  BEGIN
    INSERT INTO approvals VALUES
      ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000082','10000000-0000-4000-8000-000000000030',
       'bypass','approved',now(),now(),'10000000-0000-4000-8000-000000000002');
    RAISE EXCEPTION 'test failed: approval inserted already decided';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'approval must start pending' THEN RAISE; END IF;
  END;
END;
$$;

UPDATE approvals SET status='approved',decided_at=now(),
  decided_by='10000000-0000-4000-8000-000000000002'
  WHERE id='10000000-0000-4000-8000-000000000080';
DO $$
BEGIN
  BEGIN
    UPDATE approvals SET status='rejected' WHERE id='10000000-0000-4000-8000-000000000080';
    RAISE EXCEPTION 'test failed: approval decision changed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'approval decision is immutable' THEN RAISE; END IF;
  END;
END;
$$;

INSERT INTO run_events VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000060','10000000-0000-4000-8000-000000000030',1,'started','{}',now());
INSERT INTO audit_events VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000070',NULL,'test','10000000-0000-4000-8000-000000000030',now());
DO $$
BEGIN
  BEGIN
    UPDATE run_events SET kind='rewritten';
    RAISE EXCEPTION 'test failed: run event rewritten';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'run_events is append-only' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM run_events;
    RAISE EXCEPTION 'test failed: run event deleted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'run_events is append-only' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM audit_events;
    RAISE EXCEPTION 'test failed: audit event deleted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'audit_events is append-only' THEN RAISE; END IF;
  END;
END;
$$;
ROLLBACK;
