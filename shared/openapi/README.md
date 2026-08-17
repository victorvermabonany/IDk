# Cove API contract

`weektable-v1.yaml` is retained as the compatibility filename for the shared Cove contract used by the web client, native iOS client, and TypeScript server.

The server owns all meal constraints, grocery-provider truth, package calculations, price coverage, integer-cent totals, budget optimization, and swap repricing. Clients may cache returned snapshots and optimistic interaction state, but they must not independently declare a plan within budget.

Before production integration:

1. Serve these routes from the framework-independent TypeScript planner package.
2. Run OpenAPI linting and breaking-change checks in CI.
3. Generate Swift transport types with Apple Swift OpenAPI Generator.
4. Generate or validate TypeScript handlers from the same contract.
5. Keep `/v1` backward compatible through the initial App Store release.
