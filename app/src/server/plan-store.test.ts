import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { generatePlan, DEFAULT_PLANNER_REQUEST } from "../domain/planner-service";
import { createSwapPreviews } from "../domain/swap-service";
import { createMemoryState, MemoryStateRepository } from "./plan-store";

const queuedJob = (clientKey: string) => ({
  id: crypto.randomUUID(), planId: crypto.randomUUID(), clientKey, updates: [], status: "queued" as const,
});

describe("state repository", () => {
  it("reports real generation boundaries and factual completion metadata without percentages", async () => {
    const updates: Array<{ stage: string; metadata?: { ingredientCount?: number; productsMatched?: number; reusedIngredientCount?: number; underBudgetCents?: number } }> = [];
    const plan = await generatePlan(DEFAULT_PLANNER_REQUEST, crypto.randomUUID(), async (update) => { updates.push(update); });

    expect(updates.map((update) => update.stage)).toEqual([
      "Building your grocery list",
      "Checking your store",
      "Balancing your budget",
      "Finishing your week",
    ]);
    expect(updates.every((update) => !("progress" in update))).toBe(true);
    expect(updates.at(-1)?.metadata).toEqual({
      ingredientCount: plan.basket.length,
      productsMatched: plan.basket.filter((item) => item.product !== null).length,
      reusedIngredientCount: plan.basket.filter((item) => item.mealIds.length > 1).length,
      underBudgetCents: plan.budgetCents - plan.estimatedTotalCents,
    });
  });

  it("keeps an authoritative plan when the local repository adapter is recreated", async () => {
    const sharedState = createMemoryState();
    const firstProcess = new MemoryStateRepository(sharedState);
    const job = queuedJob("restart-client");
    await firstProcess.enqueueGeneration("stable-request", job, DEFAULT_PLANNER_REQUEST);

    const restartedAdapter = new MemoryStateRepository(sharedState);
    const claimed = await restartedAdapter.claimGeneration(job.id);
    expect(claimed?.request).toEqual(DEFAULT_PLANNER_REQUEST);
    const plan = await generatePlan(DEFAULT_PLANNER_REQUEST, job.planId);
    await restartedAdapter.completeGeneration({ ...job, status: "completed" }, plan);

    const secondRestart = new MemoryStateRepository(sharedState);
    expect((await secondRestart.getPlan(plan.id))?.constraintsUsed).toEqual(DEFAULT_PLANNER_REQUEST);
    expect((await secondRestart.getJob(job.id))?.status).toBe("completed");
  });

  it("returns the same generation job for a repeated idempotency key", async () => {
    const repository = new MemoryStateRepository();
    const firstJob = queuedJob("idempotent-client");
    await repository.enqueueGeneration("same-request", firstJob, DEFAULT_PLANNER_REQUEST);

    const secondJob = queuedJob("idempotent-client");
    expect((await repository.enqueueGeneration("same-request", secondJob, DEFAULT_PLANNER_REQUEST)).id).toBe(firstJob.id);
  });

  it("atomically reconciles pantry ownership with basket repricing", async () => {
    const repository = new MemoryStateRepository();
    const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
    const job = { ...queuedJob("grocery-client"), planId: plan.id, status: "completed" as const };
    await repository.enqueueGeneration("grocery-state", { ...job, status: "queued" }, DEFAULT_PLANNER_REQUEST);
    await repository.completeGeneration(job, plan);
    const owned = new Set([
      ...plan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.id),
      plan.basket.find((item) => item.pantryStatus === "needed")!.id,
    ]);

    const updated = await repository.updateGroceryState(plan.id, new Set(), owned);
    expect(updated!.estimatedTotalCents).toBeLessThan(plan.estimatedTotalCents);
    expect(updated!.basket.find((item) => owned.has(item.id))?.pantryStatus).toBe("already_have");
  });

  it("allows one free completed week and blocks a second generation server-side", async () => {
    const state = createMemoryState();
    const repository = new MemoryStateRepository(state);
    const first = queuedJob("free-client");
    await repository.enqueueGeneration("free-first", first, DEFAULT_PLANNER_REQUEST);
    await repository.completeGeneration({ ...first, status: "completed" }, await generatePlan(DEFAULT_PLANNER_REQUEST, first.planId));

    await expect(repository.enqueueGeneration("free-second", queuedJob("free-client"), DEFAULT_PLANNER_REQUEST))
      .rejects.toMatchObject({ code: "PREMIUM_REQUIRED", feature: "another_week" });
  });

  it("allows unlimited generations for an active Pro entitlement", async () => {
    const state = createMemoryState();
    state.clientAccess.set("pro-client", {
      entitlementStatus: "pro", entitlementExpiresAt: new Date(Date.now() + 86_400_000),
      completedPlanCount: 0, activeGenerationCount: 0, completedSwapCount: 0,
    });
    const repository = new MemoryStateRepository(state);
    for (const key of ["pro-one", "pro-two", "pro-three"]) {
      const job = queuedJob("pro-client");
      await repository.enqueueGeneration(key, job, DEFAULT_PLANNER_REQUEST);
      await repository.completeGeneration({ ...job, status: "completed" }, await generatePlan(DEFAULT_PLANNER_REQUEST, job.planId));
    }
    expect(state.clientAccess.get("pro-client")?.completedPlanCount).toBe(3);
  });

  it("keeps the first swap free and allows unlimited Pro swaps", async () => {
    const state = createMemoryState();
    const repository = new MemoryStateRepository(state);
    const freeJob = queuedJob("free-swap-client");
    const freePlan = await generatePlan(DEFAULT_PLANNER_REQUEST, freeJob.planId);
    await repository.enqueueGeneration("free-swap-plan", freeJob, DEFAULT_PLANNER_REQUEST);
    await repository.completeGeneration({ ...freeJob, status: "completed" }, freePlan);
    const firstPreviews = await createSwapPreviews(freePlan, freePlan.meals[0].id);
    await repository.savePreviews(freePlan.id, freePlan.meals[0].id, firstPreviews);
    const afterFirst = await repository.applyPreview(freePlan.id, freePlan.meals[0].id, firstPreviews[0].id, "free-swap-client");
    const secondPreviews = await createSwapPreviews(afterFirst!, afterFirst!.meals[0].id);
    await repository.savePreviews(afterFirst!.id, afterFirst!.meals[0].id, secondPreviews);
    await expect(repository.applyPreview(afterFirst!.id, afterFirst!.meals[0].id, secondPreviews[0].id, "free-swap-client"))
      .rejects.toMatchObject({ code: "PREMIUM_REQUIRED", feature: "additional_swap" });

    state.clientAccess.set("pro-swap-client", {
      entitlementStatus: "pro", completedPlanCount: 0, activeGenerationCount: 0, completedSwapCount: 12,
    });
    const proJob = queuedJob("pro-swap-client");
    const proPlan = await generatePlan(DEFAULT_PLANNER_REQUEST, proJob.planId);
    await repository.enqueueGeneration("pro-swap-plan", proJob, DEFAULT_PLANNER_REQUEST);
    await repository.completeGeneration({ ...proJob, status: "completed" }, proPlan);
    const proPreviews = await createSwapPreviews(proPlan, proPlan.meals[0].id);
    await repository.savePreviews(proPlan.id, proPlan.meals[0].id, proPreviews);
    await expect(repository.applyPreview(proPlan.id, proPlan.meals[0].id, proPreviews[0].id, "pro-swap-client")).resolves.toBeDefined();
  }, 60_000);
});
