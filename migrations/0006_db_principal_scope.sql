-- Defense in depth against caller-writable app.workspace_id settings.
--
-- PostgreSQL custom GUC values are NOT authentication. An untrusted SQL
-- principal can set app.workspace_id to any UUID it knows. Require an
-- independently provisioned database-login-principal authorization too.
--
-- This is a DB principal/workspace admission fence, not end-user RBAC.
-- An application login granted many workspaces still needs authenticated
-- per-request authorization in trusted server code; never expose that
-- privileged connection or raw SQL to untrusted clients.
--
-- Applied by a separately privileged migration owner. Runtime roles must
-- be NOSUPERUSER, NOBYPASSRLS, non-owners, without DDL/SET ROLE grants.

CREATE TABLE ores_db_principal_workspaces (
  db_principal name NOT NULL,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (db_principal, workspace_id)
);

-- Only the migration/security administrator can provision principals.
-- This table must not be granted to ordinary runtime roles.
REVOKE ALL ON TABLE ores_db_principal_workspaces FROM PUBLIC;

-- SECURITY DEFINER only reads the protected ACL. The login identity is
-- session_user (not current_user or any custom GUC), so SET ROLE and SQL
-- injection cannot switch its identity for a non-superuser connection.
-- Lock search_path and schema-qualify the ACL reference to prevent hijacks.
CREATE FUNCTION ores_db_principal_authorized(requested_workspace uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.ores_db_principal_workspaces AS a
    WHERE a.db_principal = session_user::name
      AND a.workspace_id = requested_workspace
  );
$$;

-- No implicit access to the SECURITY DEFINER entry point. Provision each
-- intended runtime role with GRANT EXECUTE; otherwise the policy fails closed.
REVOKE ALL ON FUNCTION ores_db_principal_authorized(uuid) FROM PUBLIC;

-- A RESTRICTIVE policy intersects the existing workspace_isolation policy.
-- Creating another PERMISSIVE policy here would be a security bypass because
-- PostgreSQL OR-combines permissive policies.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['memberships','workflows','workflow_versions','publications',
    'connector_versions','credentials','triggers','trigger_events','runs','step_attempts',
    'jobs','run_events','approvals','artifacts','document_extractions','desktop_tasks',
    'sessions','outbox','audit_events']
  LOOP
    EXECUTE format(
      'CREATE POLICY verified_db_login ON %I AS RESTRICTIVE FOR ALL TO PUBLIC '
      || 'USING (public.ores_db_principal_authorized(workspace_id)) '
      || 'WITH CHECK (public.ores_db_principal_authorized(workspace_id))', t
    );
  END LOOP;
END;
$$;

-- The non-workspace-scoped workspaces table itself has no RLS policy yet.
-- Only admin roles should get direct access; runtime API reads should use
-- constrained workspace-scoped relations or trusted server projections.
REVOKE ALL ON TABLE workspaces FROM PUBLIC;
