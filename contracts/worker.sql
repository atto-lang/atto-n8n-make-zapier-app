-- Execute in a transaction with app.workspace_id set after authorization.
-- $1: worker identity, $2: lease seconds (validated 1..300).
-- SKIP LOCKED lets other workers progress. Expired leases may be reclaimed.
WITH next AS (
  SELECT workspace_id, id FROM jobs
  WHERE NOT done AND available_at <= now()
    AND (lease_until IS NULL OR lease_until < now())
  ORDER BY available_at, id FOR UPDATE SKIP LOCKED LIMIT 1
)
UPDATE jobs j SET lease_owner = $1, lease_until = now() + make_interval(secs => $2),
  fence = fence + 1
FROM next WHERE j.workspace_id = next.workspace_id AND j.id = next.id
RETURNING j.*;

-- $1 workspace, $2 job, $3 owner, $4 expected fence. Zero rows = lost lease.
-- Only if this succeeds may the SAME transaction persist outputs/events.
UPDATE jobs SET done = true, lease_owner = NULL, lease_until = NULL
WHERE workspace_id = $1 AND id = $2 AND lease_owner = $3 AND fence = $4
  AND lease_until > now() AND NOT done
RETURNING id;
