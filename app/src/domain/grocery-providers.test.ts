import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { coveEstimateProvider } from "./cove-estimate-provider";
import { providerForStore } from "./grocery-providers";
import { generatePlan, DEFAULT_PLANNER_REQUEST } from "./planner-service";
import { createSwapPreviews } from "./swap-service";

const originalMode = process.env.COVE_RUNTIME_MODE;
const originalLive = process.env.OPENAI_LIVE_PLANNING_ENABLED;

afterEach(() => {
  if (originalMode === undefined) delete process.env.COVE_RUNTIME_MODE; else process.env.COVE_RUNTIME_MODE = originalMode;
  if (originalLive === undefined) delete process.env.OPENAI_LIVE_PLANNING_ENABLED; else process.env.OPENAI_LIVE_PLANNING_ENABLED = originalLive;
});

describe("grocery provider boundaries", () => {
  it("uses Cove estimates with structured provenance and a larger safety margin", async () => {
    process.env.COVE_RUNTIME_MODE = "staging_live";
    process.env.OPENAI_LIVE_PLANNING_ENABLED = "false";
    const store = (await coveEstimateProvider.findStores("45202"))[0];
    const plan = await generatePlan({
      ...DEFAULT_PLANNER_REQUEST,
      store: { id: store.id, locationId: store.providerStoreId, postalCode: "45202" },
    });

    expect(plan.priceKind).toBe("estimated");
    expect(plan.pricingProvenance.provider).toBe("cove_estimate");
    expect(plan.pricingProvenance.pricingMode).toBe("estimated");
    expect(plan.internalTargetCents).toBe(Math.round(plan.budgetCents * 0.88));
    expect(plan.basket.every((item) => item.product?.provider === "cove_estimate" || item.pantryStatus === "already_have")).toBe(true);
  });

  it("rejects fixture stores outside explicit development fixture mode", () => {
    process.env.COVE_RUNTIME_MODE = "production_live";
    expect(() => providerForStore(DEFAULT_PLANNER_REQUEST.store)).toThrow(/Fixture stores are not permitted/);
  });

  it("reprices swaps through the plan provider instead of fixture pricing", async () => {
    process.env.COVE_RUNTIME_MODE = "staging_live";
    process.env.OPENAI_LIVE_PLANNING_ENABLED = "false";
    const store = (await coveEstimateProvider.findStores("45202"))[0];
    const plan = await generatePlan({
      ...DEFAULT_PLANNER_REQUEST,
      store: { id: store.id, locationId: store.providerStoreId, postalCode: "45202" },
      dinnerCount: 3,
    });
    const previews = await createSwapPreviews(plan, plan.meals[0].id);
    expect(previews.length).toBeGreaterThan(0);
    expect(previews.flatMap((preview) => preview.basket).every((item) => item.product?.provider === "cove_estimate" || item.pantryStatus === "already_have")).toBe(true);
  });
});
