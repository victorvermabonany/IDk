-- The weektable_* table names intentionally remain for compatibility with beta data.
-- Cove is the product name; renaming durable tables would add migration risk without user benefit.
ALTER TABLE weektable_plans
  ADD COLUMN IF NOT EXISTS constraints_snapshot jsonb,
  ADD COLUMN IF NOT EXISTS pricing_provenance jsonb,
  ADD COLUMN IF NOT EXISTS model_metadata jsonb;

ALTER TABLE weektable_generation_jobs
  ADD COLUMN IF NOT EXISTS request_snapshot jsonb;

CREATE INDEX IF NOT EXISTS weektable_grocery_state_updated_at_idx ON weektable_grocery_state(updated_at);
CREATE INDEX IF NOT EXISTS weektable_idempotency_expires_at_idx ON weektable_idempotency_keys(expires_at);
CREATE INDEX IF NOT EXISTS weektable_support_expires_at_idx ON weektable_support_requests(expires_at);
