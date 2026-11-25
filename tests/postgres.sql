BEGIN;
INSERT INTO workspaces VALUES ('00000000-0000-4000-8000-000000000001','A',now()),('00000000-0000-4000-8000-000000000002','B',now());
INSERT INTO workflows VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000010','Review invoice',1,false,now());
INSERT INTO workflow_versions VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010',1,'{}',repeat('a',64),now());
INSERT INTO runs VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000020',NULL,'event-1','queued','{}',now(),NULL);
DO $$
BEGIN
  BEGIN
    UPDATE workflow_versions SET number=2;
    RAISE EXCEPTION 'test failed: mutated immutable version';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'workflow versions are immutable; create a new version' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO runs SELECT workspace_id,'00000000-0000-4000-8000-000000000031',workflow_id,version_id,NULL,idempotency_key,status,input,created_at,finished_at FROM runs;
    RAISE EXCEPTION 'test failed: duplicate run';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN
    UPDATE runs SET status='succeeded', finished_at=now();
    RAISE EXCEPTION 'test failed: skipped running state';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE 'invalid run transition:%' THEN RAISE; END IF;
  END;
  BEGIN
    INSERT INTO publications VALUES ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000020',now());
    RAISE EXCEPTION 'test failed: cross-workspace reference';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END $$;
UPDATE runs SET status='running';
UPDATE runs SET status='succeeded',finished_at=now();
DO $$ BEGIN
 BEGIN
  UPDATE runs SET status='running',finished_at=NULL;
  RAISE EXCEPTION 'test failed: reopened terminal run';
 EXCEPTION WHEN raise_exception THEN
  -- Migration 0005 adds an earlier terminal immutability guard; do not
  -- mistake the new correct rejection for a failed SQL assertion.
  IF SQLERRM NOT IN ('terminal run is immutable', 'invalid run transition: succeeded -> running') THEN RAISE; END IF;
 END;
END $;
CREATE ROLE ores_test_client NOLOGIN NOSUPERUSER NOBYPASSRLS;
GRANT SELECT, INSERT ON workflows TO ores_test_client;
SET LOCAL ROLE ores_test_client;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM workflows) THEN RAISE EXCEPTION 'missing workspace leaked rows'; END IF;
END $$;
SELECT set_config('app.workspace_id','00000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM workflows) THEN RAISE EXCEPTION 'wrong workspace leaked rows'; END IF;
 BEGIN
  INSERT INTO workflows VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011','bad',1,false,now());
  RAISE EXCEPTION 'test failed: RLS insert';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('app.workspace_id','00000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM workflows) <> 1 THEN RAISE EXCEPTION 'authorized workspace missing row'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
