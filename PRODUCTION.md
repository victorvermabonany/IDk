# Cove production runbook

## Backend deployment

Deploy `app/` to any HTTPS Node 22 host with outbound HTTPS and PostgreSQL. The simplest portable path is the checked-in Dockerfile.

1. Provision PostgreSQL and set `DATABASE_URL`.
2. Configure `COVE_RUNTIME_MODE=staging_live` or `production_live`, `OPENAI_API_KEY`, `OPENAI_LIVE_PLANNING_ENABLED=true`, and `NEXT_PUBLIC_SITE_URL=https://...`.
3. Run `pnpm install --frozen-lockfile`, `pnpm db:migrate`, `pnpm build`, and `pnpm start`.
4. Verify `GET /v1/health`, `/privacy`, `/terms`, and `/support` over HTTPS.

Optional guardrails include `COVE_PLAN_RETENTION_DAYS`, model timeout/output limits, generation concurrency, and live/estimate budget target percentages.

## Database

`pnpm db:migrate` applies ordered SQL files transactionally and records them in `cove_schema_migrations`. Existing `weektable_*` tables intentionally remain compatible with beta data. Plan JSON snapshots are authoritative; dedicated constraint, provenance, model, grocery, idempotency, preview, job, and support storage supports operations and auditing.

## OpenAI

The server uses Responses API structured output, a bounded retry, timeout, and output limit. Candidates pass independent serving, allergy, diet, disliked-food, cooking-time, package, price-coverage, pantry, and budget validation. The key never enters web client or iOS code.

## Grocery providers

Kroger access requires an approved Kroger Developer application and OAuth2 client credentials (`KROGER_CLIENT_ID`, `KROGER_CLIENT_SECRET`) with product access. Location-specific data is treated as live only when Kroger returns it. Unsupported stores use `CoveEstimateProvider`; production never uses `FixtureProvider`.

## iOS and Appetize

Use `COVE_RUNTIME_MODE=STAGING_LIVE` plus the four HTTPS Cove URL build settings for a live Appetize build. Use `PRODUCTION_LIVE` for Release/TestFlight. The pre-build gate rejects missing URLs and fixture repository references. Target/scheme/bundle identifiers remain legacy-compatible; the installed display name is Cove.

## Legal, support, and operations

Deploy `/privacy`, `/terms`, and `/support`, then configure those public URLs in iOS. Support submissions are validated, rate-limited, and stored for review; automatic email delivery is not configured.

Rate limiting and active-generation concurrency are process-local. Structured logs provide safe categories and latency, but no commercial monitoring destination is configured. Generation requests are persisted before model work starts. A leased job survives a process restart and is reclaimed on the next client poll after its lease expires; completed jobs and plans remain durable. A continuously running external worker is optional future hardening for installations that need recovery without any client reconnecting.
