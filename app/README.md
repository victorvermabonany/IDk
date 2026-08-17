# Weektable

A mobile-first weekly dinner and grocery planner that works backward from a store, household, budget, and food constraints. This repository is the first complete vertical slice: landing, four-step planner, staged generation, weekly plan, recipe detail, package-aware grocery list, pantry subtotal updates, and deterministic meal-swap repricing.

The prototype deliberately labels its grocery data as a **demo catalog**. It never presents fixture prices as current store quotes.

## Run locally

Requirements: Node.js 20+ and pnpm.

```bash
pnpm install
pnpm dev
```

Open `http://localhost:3000`.

## Verify

```bash
pnpm test
pnpm typecheck
pnpm lint
pnpm build
```

The domain tests cover canonical ingredient aliases, cross-unit consolidation, whole-package rounding, and pantry exclusion from the subtotal.

## AI planning mode

The default journey uses deterministic meal fixtures so grocery/catalog truth can be tested without an LLM dependency. The OpenAI recipe proposer is server-only and constrained to ingredient IDs that exist in the catalog.

To exercise that path, provide server-side values matching `.env.example` and set:

```text
OPENAI_LIVE_PLANNING_ENABLED=true
```

The proposer uses the OpenAI Responses API with Zod structured outputs. Its output still passes independent time, serving, allergy, ingredient, package, price-coverage, and budget checks. It cannot write product prices or package sizes.

## Grocery-provider boundary

`GroceryProvider` exposes store search, product search, and product lookup. The current implementation is a deterministic fixture provider. The intended data sequence is:

1. Prove one live Kroger-family store and geography.
2. Pursue Instacart Developer Platform access for broader retailer coverage.
3. Add providers without changing the planner, basket engine, or UI contracts.

Every product carries source, store, package quantity, integer-cent price, availability, price kind, and observed timestamp. Missing material prices cause generation failure; they are never treated as zero.

## Important limitations

- Fixture grocery prices are for product testing only.
- Nutrition values are planning estimates, not medical guidance.
- Users must verify packaged-food labels and cross-contact warnings.
- Authentication, saved plans, PostgreSQL persistence, analytics, durable generation jobs, live retailer credentials, and USDA nutrition integration belong to the next implementation phases.

See the sibling `ARCHITECTURE.md` for the full product, data, model, database, UX, design-system, rollout, and risk decisions.
