CREATE TABLE IF NOT EXISTS weektable_plans (
  id text PRIMARY KEY,
  snapshot jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS weektable_generation_jobs (
  id text PRIMARY KEY,
  plan_id text NOT NULL REFERENCES weektable_plans(id) ON DELETE CASCADE,
  updates jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS weektable_idempotency_keys (
  key_hash text PRIMARY KEY,
  job_id text NOT NULL REFERENCES weektable_generation_jobs(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS weektable_swap_previews (
  id text PRIMARY KEY,
  plan_id text NOT NULL REFERENCES weektable_plans(id) ON DELETE CASCADE,
  meal_id text NOT NULL,
  snapshot jsonb NOT NULL,
  expires_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS weektable_grocery_state (
  plan_id text PRIMARY KEY REFERENCES weektable_plans(id) ON DELETE CASCADE,
  checked_item_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  owned_item_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS weektable_plans_expires_at_idx ON weektable_plans(expires_at);
CREATE INDEX IF NOT EXISTS weektable_jobs_expires_at_idx ON weektable_generation_jobs(expires_at);
CREATE INDEX IF NOT EXISTS weektable_previews_expires_at_idx ON weektable_swap_previews(expires_at);

CREATE TABLE IF NOT EXISTS weektable_support_requests (
  id text PRIMARY KEY,
  contact_email text NOT NULL,
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS weektable_support_expires_at_idx ON weektable_support_requests(expires_at);
