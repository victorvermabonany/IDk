-- A generation job is persisted before its plan exists. The reserved plan_id
-- remains stable for the client, so the beta FK is intentionally removed.
ALTER TABLE weektable_generation_jobs
  DROP CONSTRAINT IF EXISTS weektable_generation_jobs_plan_id_fkey;

ALTER TABLE weektable_generation_jobs
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS lease_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS error_code text,
  ADD COLUMN IF NOT EXISTS error_message text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'weektable_generation_jobs_status_check'
  ) THEN
    ALTER TABLE weektable_generation_jobs
      ADD CONSTRAINT weektable_generation_jobs_status_check
      CHECK (status IN ('queued', 'running', 'completed', 'failed'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS weektable_generation_jobs_status_lease_idx
  ON weektable_generation_jobs(status, lease_expires_at);
