# Cove V1 product, architecture, and design brief

Status: implementation-approved. Cove is the current product name; legacy Weektable technical identifiers remain only where compatibility requires them.

## 1. Product understanding

Cove is a constraint-solving grocery and dinner-planning product. A user supplies where they shop, what they can spend, how many people and dinners they need to feed, and the food constraints that matter. The product returns a complete, purchasable week: distinct recipes, consolidated ingredients, full package quantities, matched products, a defensible estimated basket total, and a grocery list designed for one-handed use in a store.

The product is not recipe search, a chatbot, or a calorie tracker. Its promise is that the weekly planning problem has been handled. The core experience is:

1. Enter constraints in a short progressive planner.
2. Watch meaningful generation stages without fake technical theater.
3. Land on an editorial weekly plan that leads with food and quietly proves the budget.
4. Shop from a consolidated, package-aware list.
5. Open clear recipes and swap one dinner without breaking the rest of the week.

Weekly return-plan generation is the primary success signal. Activation is planner completion plus opening the grocery list; plan correctness and price coverage are prerequisites for retention.

### V1 scope adjustments

V1 should be narrower than the full acceptance list in four ways:

- Launch with one live retailer family and a small explicit ZIP coverage area. “Every store” is not credible before provider access and matching quality are proven.
- Treat a plan as price-complete only when every material shopping item has a price. Never count an unpriced item as zero; allow a visibly labeled incomplete estimate only in internal testing.
- Keep nutrition descriptive and approximate through USDA data. Do not optimize micronutrients or make health claims.
- Defer accounts until the save action, and defer direct retailer carts, checkout, loyalty, coupons, and automatic pantry inventory.

No question blocks the first vertical slice. Retailer/provider contracting, launch ZIPs, final name, authentication vendor, and analytics vendor remain launch decisions.

## 2. Recommended stack

- **Web:** Next.js App Router, React, and strict TypeScript. Server components keep initial pages fast; client components are reserved for the planner, checkoffs, swap sheet, and local optimistic updates.
- **Styling:** Tailwind CSS plus a small token layer in CSS. Components are custom to this product; no generic dashboard kit.
- **Validation:** Zod at every external boundary: forms, route handlers, model output, provider responses, and persisted JSON snapshots.
- **Database:** PostgreSQL with Drizzle ORM. Postgres supports precise numeric quantities, JSON snapshots, transactional swaps, and future queue/analytics workloads without introducing a second database.
- **Jobs:** A durable background job boundary for plan generation (managed queue in production; synchronous adapter in the first slice). Generation must be idempotent and resumable.
- **AI:** OpenAI Responses API with structured outputs and Zod schemas. Official guidance supports `responses.parse` with `zodTextFormat`; refusals and invalid output are handled explicitly. See [OpenAI structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs).
- **Auth:** Auth.js or Clerk, introduced only when saving. Anonymous planner sessions use a signed, short-lived session ID.
- **Analytics:** PostHog or a warehouse-first event sink behind an analytics adapter. Allergy strings never enter general event properties.
- **Testing:** Vitest for deterministic domain logic, Testing Library for interactions, Playwright for the mobile planning journey, and axe checks for critical screens.
- **Deployment:** Vercel is the lowest-friction web deployment; managed Postgres and a managed queue must live in the same region. The domain layer remains framework-independent for a future native API.

## 3. System architecture

The application is organized as a modular monolith for V1, not premature microservices:

```text
Next.js UI / Route Handlers
        |
        v
Plan Application Service  -----> Plan Job / idempotency state
        |
        +----> Recipe Proposal Port ----> OpenAI structured output
        +----> Constraint Validator (hard allergies, diet, time, servings)
        +----> Ingredient Canonicalizer + Unit Converter
        +----> Grocery Provider Port ----> Fixture / Kroger / Instacart
        +----> Product Matcher + Package Solver
        +----> Budget Optimizer (bounded retries, deterministic totals)
        +----> Nutrition Port ----> USDA FoodData Central
        |
        v
PostgreSQL snapshots + normalized operational data
```

Generation data flow:

1. Validate and store an immutable request snapshot before doing slow work.
2. Ask the model for several structured recipe candidates, never prices or availability.
3. Reject candidates that violate allergies, diet, servings, time, equipment, or duplication rules.
4. Canonicalize and consolidate ingredient quantities using authoritative aliases and unit conversions.
5. Search the chosen store through the grocery-provider interface and rank candidate products.
6. Convert each requirement into integer package counts. Money is stored and calculated in integer cents; food quantities use decimals plus normalized units.
7. Sum purchasable packages and compare to an internal target of roughly 92–95% of budget.
8. If needed, run a bounded optimization loop: cheaper product, substitution, overlap increase, garnish removal, then a meal replacement. Revalidate after every attempt.
9. Persist the final recipes and a price snapshot with provider and timestamp. Return an actionable failure if a complete plan cannot be produced.

Swaps run as transactions: compute the proposed delta first, remove only orphaned requirements, rematch only affected ingredients, validate the new total and constraints, then atomically replace the meal and basket snapshot.

## 4. Grocery data strategy

### Available approaches

- **Direct retailer API:** strongest provenance and typically the clearest store IDs, package size, current price, promotion, and availability. Coverage is retailer-specific and access/rate limits vary. Kroger’s official public API workspace documents that product price, availability, and aisle require `filter.locationId`; its product results expose store-scoped purchasable items. See [Kroger’s official Postman workspace](https://www.postman.com/kroger/the-kroger-co-s-public-workspace/request/ft2k63q/product-list).
- **Approved aggregator:** best path to multi-retailer coverage. Instacart’s current Developer Platform explicitly advertises nearby retailers, available products, real-time inventory and pricing, and meal-planning/shopping-list use cases. Production access is partnership-gated and its own onboarding guide estimates roughly 30–40 days to demo approval and production access. See [Instacart Developer Platform](https://docs.instacart.com/developer_platform_api) and [getting started](https://docs.instacart.com/developer_platform_api/get_started/overview).
- **Licensed catalog/feed:** useful when a retailer or data vendor provides regular snapshots. It needs freshness SLAs and often lacks precise store-level availability.
- **Controlled estimate provider:** acceptable only as a disclosed fallback or demo mode. It must return `estimated` provenance, confidence, coverage, and timestamp; estimates can never be presented as current store prices.
- **Scraping:** rejected unless a retailer supplies explicit written permission and an integration contract. Browser scraping is fragile, operationally expensive, and can violate retailer terms.

### Recommended V1 sequence

1. Apply for Instacart Developer Platform access immediately because it most closely matches the eventual multi-retailer product.
2. Prove the live vertical slice with one Kroger-family banner and one launch geography if Kroger credentials can be obtained sooner.
3. Keep a deterministic fixture provider for development and CI. Fixture screens must say “demo catalog” and never imply current prices.
4. Support additional retailers only after per-store product-match accuracy, price coverage, and package parsing meet launch thresholds.

### Provider contract

```ts
interface GroceryProvider {
  findStores(input: ZipSearch): Promise<ProviderStore[]>;
  searchProducts(input: ProductSearch): Promise<ProviderProduct[]>;
  getProduct(input: ProductLookup): Promise<ProviderProduct | null>;
  health(): Promise<ProviderHealth>;
}
```

Every returned offer includes provider/store/product IDs, normalized and display package quantities, regular and promotional price in cents, availability as `in_stock | out_of_stock | unknown`, aisle/department when present, image source, source URL/reference, price kind (`live | feed | estimated | fixture`), observed timestamp, and raw-response checksum. The rest of the application consumes only this contract.

### First proof of concept

Use one ZIP and one real store. Search ten canonical ingredients, verify the selected store, parse at least pounds/ounces/count/fluid ounces, rank products, solve package counts for a three-meal basket, and record:

- match correctness at top 1 and top 3;
- package parsing coverage;
- price and availability coverage;
- time-to-first and cached latency;
- behavior for variable-weight meat/produce, sale prices, and missing products.

Do not build the full planner until this proof reaches agreed thresholds (suggested: 90% top-3 match, 95% package parsing, 100% priced material items for a returned “within budget” claim).

## 5. AI/model strategy

Use the model for recipe candidates, preference interpretation, cuisine variety, concise descriptions, sensible instructions, overlap suggestions, and alternative substitutions after the price engine reports a problem.

Do not use the model for store truth, prices, availability, package size, arithmetic, final nutrition, allergy clearance, canonical identity, user persistence, or final validation.

The recipe-proposal schema requires bounded arrays and explicit servings, preparation/cooking minutes, equipment, dietary tags, allergen candidates, and ingredients with numeric quantity and allowed units. The server parses structured output, handles refusal/timeout/invalid schema, and then applies independent domain validation. A valid schema is not the same as a safe plan.

The optimizer is a bounded state machine, not an open-ended agent. It gets a compact feedback object containing expensive requirements and reusable ingredients, proposes one allowed change, and stops after a small retry budget. Deterministic code accepts or rejects each change. Store snapshots are never included in model-writable output.

Model choice is configurable through `OPENAI_PLANNER_MODEL`; start with a current structured-output-capable general model and pin a snapshot before beta. Keep an evaluation set covering allergies, conflicting restrictions, very low budgets, ingredient aliases, package rounding, cuisine variety, and swap deltas.

## 6. Database structure

Core tables:

- `users`, `user_preferences`, `auth_accounts` — optional identity and reusable defaults.
- `planner_sessions`, `plan_requests` — anonymous/session ownership plus immutable user input and validation version.
- `stores` — canonical store identity, retailer, provider mapping, address, ZIP, capabilities.
- `products` — provider-independent product identity where possible.
- `store_product_offers` — store-specific package, price, promotion, availability, provenance, and observation time.
- `ingredients`, `ingredient_aliases`, `ingredient_allergens` — canonical food identity and deterministic matching vocabulary.
- `recipes`, `recipe_ingredients`, `recipe_steps` — structured recipe content and validation version.
- `meal_plans`, `plan_meals` — request, budget/internal target in cents, total, coverage, status, ordering/day assignment.
- `grocery_requirements` — consolidated normalized quantity, meals using it, pantry exclusion.
- `basket_items` — selected offer, package count, total cents, match score/reason, price snapshot.
- `nutrition_snapshots` — source IDs, nutrients, serving basis, observation/calculation version.
- `generation_runs`, `generation_attempts` — idempotency key, stage, errors, model/provider metadata without sensitive prompts in analytics.
- `grocery_checkoffs`, `plan_events` — user interactions and auditable plan mutations.

Use UUIDs, `numeric` for ingredient quantities, integers for cents and minute counts, and timestamps with time zones. Preserve raw provider payloads only in access-controlled, expiring storage; operational rows keep normalized fields and a checksum. Recipes and basket snapshots are versioned so old saved plans do not silently change when provider data refreshes.

## 7. Frontend architecture

Routes:

- `/` — landing and product preview.
- `/plan` — progressive planner; URL/state identifies the current step.
- `/plan/generating` — resumable job progress.
- `/plans/[planId]` — weekly plan.
- `/plans/[planId]/groceries` — store-mode grocery list.
- `/plans/[planId]/meals/[mealId]` — recipe detail.
- `/plans/[planId]/meals/[mealId]/swap` — intercepted route rendered as a mobile sheet/desktop side panel.
- `/saved` and `/account` — introduced with persistence.

Server components load complete plan snapshots. Route handlers/actions own mutation and authorization. TanStack Query is unnecessary for most reads; use focused client state and optimistic updates for checkoffs, pantry toggles, and swap preview. React Hook Form plus Zod manages planner inputs. Planner state is mirrored to `sessionStorage` and periodically saved server-side so failures and refreshes do not erase answers.

Cache reference/fixture catalog data aggressively, store-scoped live offers briefly, and never cache personalized plan responses across users. Generation uses idempotency keys; completed plans are read from storage instead of regenerating.

## 8. Visual direction

The visual idea is **the practical weekly food journal**: warm paper, market-ink typography, close-cropped food, disciplined rules, and a restrained tomato accent. It should feel like a beautifully edited cookbook crossed with a dependable shopping list—not a dashboard and not an AI product.

The interface uses few containers. Page structure comes from typography, image crops, rules, and background shifts. Budget appears as one legible sentence near the plan title. Food titles and day labels establish the rhythm. Desktop uses editorial two-column compositions where useful; mobile remains a deliberate vertical flow with a sticky action area only when it helps the current task.

## 9. Design system

- **Type:** Newsreader for display/meal titles; DM Sans for controls, body copy, numbers, and dense grocery rows. Display 56/58 desktop and 40/42 mobile; H1 40/44 and 34/38; H2 28/32 and 25/29; body 17/26; compact body 15/22; caption 12/16 with tracking. Prices use tabular numerals and medium weight.
- **Color:** oat `#F5F0E7` page; warm white `#FFFDF8` working surface; ink `#25241F`; muted ink `#6F6A60`; herb `#315B46`; tomato `#C24E32`; butter `#E8C86A`; rule `#D9D0C1`; error `#A43F36`. No gradients. Text/accent pairings must meet WCAG AA.
- **Spacing:** 4, 8, 12, 16, 24, 32, 48, 64, 96. Mobile page gutter 20; desktop max reading width 1200 with 32–48 gutters.
- **Radius:** 0 for structural sections and buttons, 4 for inputs and images, 10 for compact raised controls, 18 only for bottom sheets. Rounding signals an interaction or physical object, not decoration.
- **Buttons:** primary ink rectangle with warm-white text; secondary transparent with 1px ink rule; text action underlined on hover/focus; destructive text/tomato; loading preserves width and announces state; disabled uses strong enough contrast and explains why when needed.
- **Inputs:** visible labels above controls, 48px minimum height, warm-white background, ink border, tomato focus ring, inline errors. Numeric steppers expose keyboard entry. Segmented controls use connected borders, not floating pills. Multi-selects become a check-list sheet on mobile.
- **Surfaces:** oat page, warm-white work area, butter-tinted callout for incomplete pricing, dark ink footer. Modals are reserved for destructive confirmation; drawers/sheets handle selections and swaps.
- **Icons:** sparse, simple stroked glyphs for back, check, share, and disclosure. Text stays visible; icons do not decorate labels.
- **Photography:** natural window light, warm neutral surfaces, recognizable ingredients, 35–55° camera angle, close crop, honest texture, minimal props. Use consistent 4:3 plan crops and 3:2 recipe hero crops; avoid generic overhead stock mosaics.
- **Motion:** 140–220ms ease-out for navigation, checkoff, and number changes. Generation stages crossfade. Respect `prefers-reduced-motion`; no perpetual ambient motion.
- **Navigation:** compact wordmark plus one context action. Mobile plan screens use a sticky bottom action only for the primary next step. Desktop may use a narrow rail/split view on grocery and recipe screens.
- **Grocery row:** 48–56px tap target, checkbox first, product/quantity in the center, tabular price at the end, package/provenance on a second line, optional meal-use disclosure. Checked rows dim and strike through without collapsing.
- **Recipe language:** large serif title, quiet metadata line, numbered instructions with strong step numerals, and ingredient quantities aligned for scanning. Shared ingredients are explained in prose, not a badge cloud.

## 10. Screen-by-screen UX

### Landing

Goal: understand the promise and start in seconds. A concise left-aligned headline sits beside/in front of a real weekly-plan preview, followed by a three-step explanation and trust copy about prices. Mobile stacks copy, CTA, then preview; desktop uses a 5/7 split. The CTA loads instantly. If store coverage is limited, ZIP coverage is disclosed before the planner.

### Planner

Goal: supply constraints without feeling like a tax form. Use four stages: Store & budget, Household, Food, Pantry. Each screen has one dominant question cluster, persistent Back/Continue, saved answers, semantic errors, and a text summary of progress. Mobile respects numeric/email keyboards and keeps focused inputs visible; desktop uses a calm two-column layout with a running natural-language summary. Provider failures retain every answer and offer retry/change store.

### Generation

Goal: make the wait legible and recoverable. Show the five real backend stages, one at a time, with elapsed-state messaging only when warranted. Refresh resumes the job. Failure names the actionable category and returns to the relevant step without losing state. There is no fake log, terminal, or fabricated percent.

### Weekly plan

Goal: answer “what am I eating and can I afford it?” The hierarchy is title, one budget sentence, grocery CTA, then an editorial day-by-day meal list. Mobile alternates compact 4:3 images and titles with generous dividers; desktop uses a strong vertical list beside a sticky budget/grocery summary, not metric cards. Empty plans never exist; generation failures use the generation recovery state. Partial pricing is a prominent butter callout and removes the “within budget” claim.

### Grocery list

Goal: shop with one hand. A sticky compact header shows unchecked count and running basket total. Departments are semantic headings, rows have large check targets, and “already have” is available from row disclosure. Mobile is a single dense column; desktop uses categories left and a sticky basket summary right. Empty means all items are checked and celebrates quietly without hiding rows. Offline/checkoff updates queue locally; provider freshness issues do not erase the list.

### Recipe detail

Goal: cook without interpretation. Image and title lead, followed by servings/time/cost, a clear ingredients list, then numbered steps. Servings can be viewed but not silently rescaled after purchase. Mobile keeps the recipe linear; desktop places ingredients in a sticky narrow column beside steps. Missing nutrition says unavailable; it never substitutes model numbers. A swap action is secondary and clearly states that the basket will be rechecked.

### Meal swap

Goal: replace one meal safely. Present three alternatives with image, time, estimated basket delta, and one useful reuse sentence. Preview recalculates before confirmation. Mobile uses a full-height sheet; desktop uses a right panel while keeping the old meal visible. Loading uses row skeletons; no alternative is an explicit outcome with advice, not an empty carousel. Provider failure leaves the original plan untouched.

## 11. Build plan

1. **Architecture and design:** this document, tokens, schemas, provider interfaces, and domain invariants.
2. **Data proof:** fixture provider and package solver first; then one live Kroger store POC, while Instacart access is pursued.
3. **Core vertical slice:** landing → planner → staged generation → weekly plan → grocery checkoffs → recipe detail, using deterministic demo catalog data and clearly labeled provenance.
4. **Planning engine:** OpenAI structured recipe proposals, hard validation, canonicalization, provider matching, package math, bounded optimization, and eval fixtures.
5. **Swap and persistence:** transactional meal swaps, anonymous plan ownership, account-on-save, saved preferences/plans.
6. **Quality and beta:** mobile/browser coverage, accessibility, outage/error drills, analytics, performance budgets, provider legal review, and controlled geography beta.

## 12. Risks and decisions

### Technical risk

- Ingredient identity and unit conversion, especially count-to-weight and prepared/raw forms.
- Product matching ambiguity and variable-weight packages.
- Transactional swap deltas and optimizer convergence.
- Long-running generation reliability, idempotency, and price freshness.
- Allergy checks across recipe ingredients and incomplete packaged-product metadata.

### Data risk

- Retailer access, coverage, rate limits, online/in-store price differences, stale promotions, and unknown inventory.
- Package strings that cannot be parsed reliably.
- Missing allergen or nutrition fields and inconsistent department taxonomy.

### Product risk

- Users may not trust estimates enough to shop.
- Aggressive ingredient overlap can make the week repetitive.
- Low budgets can produce too many honest failures.
- Account-on-save may reduce saved-plan rate but is still preferable to gating activation.

### UX risk

- Planner length, generation wait, and dense grocery rows on small phones.
- “Estimated” pricing language may be overlooked.
- Meal swaps can feel unpredictable unless the basket delta is previewed before commitment.

### Legal/integration risk

- Provider terms may restrict caching, imagery, price display, or downstream model use.
- “Allergy-safe” and nutrition language can create inappropriate certainty.
- Food images need explicit licenses and attribution handling.
- Store trademarks and branding need provider-compliant presentation.

### Decisions before live beta

- First retailer banner and launch ZIPs.
- Instacart/Kroger commercial and API approval.
- Final brand name and trademark screening.
- Auth, analytics, queue, and hosting vendors.
- Price-completeness and product-match launch thresholds.
- Whether beta allows disclosed estimated catalogs or only fully live catalogs.

These decisions do not block the fixture-backed vertical slice. Provider credentials are the first external dependency that blocks truthful live-price testing.

