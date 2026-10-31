# Database principal authentication fence

**Status: proposed source-level hardening, not a deployed authentication system.**
This document explains migration `0006_db_principal_scope.sql` and
`tests/postgres-tenant-auth.sql`. See issue #4.

## Threat model and guarantee

Previously, `workspace_isolation` used `app.workspace_id` alone. An SQL
caller can run `SET app.workspace_id` or `set_config` to select a different
workspace. A PostgreSQL custom setting cannot authenticate a tenant.

The additive RESTRICTIVE policy uses a separate protected table mapping an
**authenticated PostgreSQL session login** to **exactly one workspace**,
intersected with the original `app.workspace_id` filter. The policy helper
uses `session_user`, not `current_user`: `SET ROLE` or a custom GUC cannot
change the original login identity of an unprivileged session. A session
principal without a mapping or function EXECUTE grant has no permitted tenant
records. `FORCE ROW LEVEL SECURITY` is retained on all 19 workspace-scoped
tables. Do not replace the RESTRICTIVE policy with a PERMISSIVE one.

The helper is SECURITY DEFINER but reads *only* the administrator-owned ACL
with a fixed `pg_catalog, pg_temp` search path. It must remain owned by a
migration/security principal, not the application login.

## Runtime provisioning (administrator-only; example)

Assign a dedicated database login/pool to each workspace. Provision the
mapping and privileges using a trusted admin process in a transaction; use
generated role names, strong credentials and authenticated TLS connections.
Never construct SQL role names from untrusted values.

```sql
-- Example only: run as the migration/security administrator. Replace the
-- sample workspace ID and role name with admin-verified provisioned values.
CREATE ROLE ores_tenant_example LOGIN PASSWORD '<admin-generated-secret>'
  NOSUPERUSER NOBYPASSRLS NOINHERIT;
INSERT INTO ores_db_principal_workspaces (db_principal,workspace_id)
VALUES ('ores_tenant_example', '00000000-0000-4000-8000-000000000001');

GRANT USAGE ON SCHEMA public TO ores_tenant_example;
GRANT EXECUTE ON FUNCTION ores_db_principal_authorized(uuid)
  TO ores_tenant_example;
GRANT SELECT ON workflows, workflow_versions TO ores_tenant_example;
-- Grant only the specific additional table operations required by the
-- reviewed server operations; never grant owner/DDL/trigger-disable rights.
```

The database **login is not the browser user**. The server must still
authenticate users, enforce membership and finer-grained role/capability
permissions, select the correct per-tenant connection, and independently
authorize every request. Do not expose a credential or SQL endpoint directly
to an untrusted browser or connector. A single pooled login shared across
tenants defeats isolation; the ACL deliberately rejects that configuration.
Database migrations use a separate privileged role, never the runtime login.

## Connection and test invariants

- Keep the explicit workspace GUC as an additional, transaction-local bound,
  set *only* after trusted application authorization, not from user inputs.
  Cancel/rollback must clear that bound; do not reuse an unclean connection.
- Treat `session_user` as the authenticated connection identity. PostgreSQL
  superusers may impersonate sessions, so only untrusted non-superuser runtime
  principals satisfy this threat model. NOINHERIT and no cross-tenant SET ROLE
  grants are required.
- Admin-only ACL mutations and credentials must have strictly limited access.
  Never grant DDL, BYPASSRLS, SUPERUSER, table ownership or trigger-disabling
  capabilities to runtime principals.
- `tests/postgres-tenant-auth.sql` runs in a disposable database under the
  test superuser and impersonates distinct authenticated session logins; it
  must verify own-tenant reads, known-victim-UUID GUC spoofing, cross-tenant
  writes, ACL mutation denial, missing-mapping denial, and unique login
  binding. Existing `tests/postgres.sql` uses the new authenticated identity
  fence for its legacy RLS assertions.
- Execution evidence must include exact commit SHA, real PostgreSQL 17 SQL
  results and CI runner step records. A GitHub job with zero steps is not a
  database test failure or pass.

## Unresolved production security work

This migration does not implement user identity, HTTP authentication, browser
sessions, API RBAC, tenant pool provisioning, SSR/WebSocket authorization,
CSRF, connector credential permissions, retention or offboarding. It is a
fail-closed **database role fence** for a future runtime, not approval to
deploy the current development HTTP server as a multi-tenant product.

A superuser/table owner/role with BYPASSRLS can bypass policies; ordinary
database login credentials remain highly sensitive. An independent security
review is required before any real secrets or connector effects are enabled.
