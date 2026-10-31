-- Adversarial PostgreSQL-only test for 0006. This script is deliberately
-- run as the disposable database superuser to provision isolated, untrusted
-- test logins and impersonate each authenticated session_user. Real clients
-- have no superuser or SET SESSION AUTHORIZATION privilege.
BEGIN;

INSERT INTO workspaces (id,name,created_at) VALUES
 ('30000000-0000-4000-8000-000000000001','Auth tenant A',now()),
 ('30000000-0000-4000-8000-000000000002','Auth tenant B',now());
INSERT INTO workflows (workspace_id,id,name,revision,archived,created_at) VALUES
 ('30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000010','A private',1,false,now()),
 ('30000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000020','B private',1,false,now());

CREATE ROLE ores_auth_alpha NOLOGIN NOSUPERUSER NOBYPASSRLS NOINHERIT;
CREATE ROLE ores_auth_beta NOLOGIN NOSUPERUSER NOBYPASSRLS NOINHERIT;
CREATE ROLE ores_auth_unmapped NOLOGIN NOSUPERUSER NOBYPASSRLS NOINHERIT;

INSERT INTO ores_db_principal_workspaces (db_principal,workspace_id) VALUES
 ('ores_auth_alpha','30000000-0000-4000-8000-000000000001'),
 ('ores_auth_beta','30000000-0000-4000-8000-000000000002');

-- The same authenticated database login must NOT have multiple workspaces.
DO $$
BEGIN
  BEGIN
    INSERT INTO ores_db_principal_workspaces (db_principal,workspace_id)
    VALUES ('ores_auth_alpha','30000000-0000-4000-8000-000000000002');
    RAISE EXCEPTION 'test failed: database principal has two workspaces';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON workflows
 TO ores_auth_alpha, ores_auth_beta, ores_auth_unmapped;
GRANT EXECUTE ON FUNCTION ores_db_principal_authorized(uuid)
 TO ores_auth_alpha, ores_auth_beta, ores_auth_unmapped;

-- Test principal A as a real (impersonated) login, not SET ROLE, because
-- the SECURITY DEFINER policy verifies session_user, not current_user.
SET SESSION AUTHORIZATION ores_auth_alpha;
SELECT set_config('app.workspace_id','30000000-0000-4000-8000-000000000001',true);
DO $$
BEGIN
  IF session_user <> 'ores_auth_alpha' THEN
    RAISE EXCEPTION 'test failed: authenticated identity mismatch';
  END IF;
  IF (SELECT count(*) FROM workflows) <> 1 THEN
    RAISE EXCEPTION 'test failed: alpha cannot see its own workspace';
  END IF;
END;
$$;

-- The attacker deliberately selects the victim's known workspace UUID.
SELECT set_config('app.workspace_id','30000000-0000-4000-8000-000000000002',true);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM workflows) THEN
    RAISE EXCEPTION 'test failed: spoofed app.workspace_id leaked beta data';
  END IF;
  BEGIN
    INSERT INTO workflows (workspace_id,id,name,revision,archived,created_at)
    VALUES ('30000000-0000-4000-8000-000000000002',
      '30000000-0000-4000-8000-000000000021','Injected',1,false,now());
    RAISE EXCEPTION 'test failed: alpha wrote a beta workflow';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO ores_db_principal_workspaces(db_principal,workspace_id)
    VALUES ('ores_auth_alpha','30000000-0000-4000-8000-000000000002');
    RAISE EXCEPTION 'test failed: untrusted principal edited ACL';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

-- Even within the same SQL transaction, changing the scope alone must not
-- grant cross-workspace access. Return to A and validate allowed reads.
SELECT set_config('app.workspace_id','30000000-0000-4000-8000-000000000001',true);
DO $$
BEGIN
  IF (SELECT count(*) FROM workflows) <> 1 THEN
    RAISE EXCEPTION 'test failed: alpha lost authorized read';
  END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION ores_auth_beta;
SELECT set_config('app.workspace_id','30000000-0000-4000-8000-000000000002',true);
DO $$
BEGIN
  IF (SELECT count(*) FROM workflows) <> 1 THEN
    RAISE EXCEPTION 'test failed: beta cannot see its own workspace';
  END IF;
END;
$$;
SELECT set_config('app.workspace_id','30000000-0000-4000-8000-000000000001',true);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM workflows) THEN
    RAISE EXCEPTION 'test failed: beta read alpha workspace';
  END IF;
END;
$$;
RESET SESSION AUTHORIZATION;

-- A role with table and function permissions but no admin-provisioned ACL
-- must still be denied all tenant records.
SET SESSION AUTHORIZATION ores_auth_unmapped;
SELECT set_config('app.workspace_id','30000000-0000-4000-8000-000000000001',true);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM workflows) THEN
    RAISE EXCEPTION 'test failed: unmapped authenticated principal had access';
  END IF;
  BEGIN
    INSERT INTO workflows (workspace_id,id,name,revision,archived,created_at)
    VALUES ('30000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000011','Unauthorized',1,false,now());
    RAISE EXCEPTION 'test failed: unmapped role wrote a workspace record';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;
RESET SESSION AUTHORIZATION;
ROLLBACK;
