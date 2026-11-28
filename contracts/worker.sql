-- Reference SQL only: NOT an active worker. Run each statement in a transaction
-- after authenticating the worker and authorizing its workspace. A transaction
-- must SET LOCAL app.workspace_id to the verified workspace; never accept it
-- from an arbitrary caller, since PostgreSQL custom GUCs are not credentials.
-- Use a non-superuser NOBYPASSRLS runtime role; never the migration owner.
--
-- CLAIM: $1 workspace UUID, $2 stable worker ID, $3 lease seconds (1..300).
-- Validate parameters BEFORE issuing this query. The explicit workspace filter
-- is defense in depth, not a replacement for RLS or server-side authorization.
-- A newly claimed queued run must transition to running in the SAME transaction
-- before any external effects are attempted.
WITH candidate AS (
  SELECT j.workspace_id, j.id
  FROM jobs AS j
  JOIN runs AS r ON r.workspace_id = j.workspace_id AND r.id = j.run_id
  WHERE j.workspace_id = $1::uuid
    AND r.status IN ('queued', 'running')
    AND NOT j.done
    AND j.available_at <= now()
    AND (j.lease_until IS NULL OR j.lease_until <= now())
    AND j.fence < 9223372036854775807
  ORDER BY j.available_at, j.id
  FOR UPDATE OF j SKIP LOCKED
  LIMIT 1
)
UPDATE jobs AS j
SET lease_owner = $2::text,
    lease_until = now() + make_interval(secs => $3::integer),
    fence = j.fence + 1
FROM candidate
WHERE j.workspace_id = candidate.workspace_id AND j.id = candidate.id
  AND length($2::text) BETWEEN 1 AND 128
  AND $3::integer BETWEEN 1 AND 300
RETURNING j.*;

-- COMPLETE: $1 verified workspace UUID, $2 job UUID, $3 worker ID,
-- $4 expected fence. Zero rows means stale/lost lease or unauthorized scope.
-- Require exactly one row; only then may the SAME transaction commit outputs,
-- successors, run state and append-only events. Do not perform API calls while
-- holding DB row locks. A valid fence does not guarantee once-only effects.
UPDATE jobs AS j
SET done = true, lease_owner = NULL, lease_until = NULL
WHERE j.workspace_id = $1::uuid
  AND j.id = $2::uuid
  AND j.lease_owner = $3::text
  AND j.fence = $4::bigint
  AND j.lease_until > now()
  AND NOT j.done
  AND EXISTS (
    SELECT 1 FROM runs AS r
    WHERE r.workspace_id = j.workspace_id AND r.id = j.run_id
      AND r.status = 'running'
  )
RETURNING j.id, j.run_id, j.fence;
