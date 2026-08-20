CREATE TABLE IF NOT EXISTS weektable_client_access (
  client_key text PRIMARY KEY,
  entitlement_status text NOT NULL DEFAULT 'free',
  entitlement_expires_at timestamptz,
  completed_plan_count integer NOT NULL DEFAULT 0 CHECK (completed_plan_count >= 0),
  active_generation_count integer NOT NULL DEFAULT 0 CHECK (active_generation_count >= 0),
  completed_swap_count integer NOT NULL DEFAULT 0 CHECK (completed_swap_count >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (entitlement_status IN ('free', 'pro', 'expired', 'revoked'))
);

ALTER TABLE weektable_generation_jobs
  ADD COLUMN IF NOT EXISTS client_key text;

ALTER TABLE weektable_plans
  ADD COLUMN IF NOT EXISTS client_key text;

CREATE INDEX IF NOT EXISTS weektable_generation_jobs_client_key_idx
  ON weektable_generation_jobs(client_key);

CREATE INDEX IF NOT EXISTS weektable_plans_client_key_idx
  ON weektable_plans(client_key);
