# Cove backend and web product

Cove is a server-authoritative weekly meal and grocery planner: **Your week, planned.** The Next.js application contains the public site, planner, versioned API, legal/support routes, and PostgreSQL-backed production state.

## Local fixture development

Requirements: Node.js 22+ and pnpm.

```bash
pnpm install
pnpm dev
```

`development_fixture` is the only runtime mode that may use `FixtureProvider`. Fixture prices are visibly identified and are not current store prices.

## Production setup

Configure the variables in `.env.example`, then run:

```bash
pnpm db:migrate
pnpm build
pnpm start
```

The Dockerfile produces a provider-neutral standalone Node container. Run migrations as a release command; application startup does not mutate the schema.

## Grocery modes

- `KrogerProvider`: official Kroger Public API client credentials through `KROGER_CLIENT_ID` and `KROGER_CLIENT_SECRET`.
- `CoveEstimateProvider`: clearly labeled category/package estimates for unsupported retailers, with a larger budget margin.
- `FixtureProvider`: deterministic development/test data only.

The server—not the provider—calculates packages, extended costs, basket total, and budget fit.

## Verification

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
```

Set `RUN_LIVE_OPENAI_TESTS=true` only for the controlled server-side integration test. See `../PRODUCTION.md` for the complete runbook.
