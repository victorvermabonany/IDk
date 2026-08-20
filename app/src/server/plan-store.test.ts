import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { generatePlan, DEFAULT_PLANNER_REQUEST } from "../domain/planner-service";
import { createMemoryState, MemoryStateRepository } from "./plan-store";

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
    const job = { id: crypto.randomUUID(), planId: crypto.randomUUID(), updates: [], status: "queued" as const };
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
    const firstJob = { id: crypto.randomUUID(), planId: crypto.randomUUID(), updates: [], status: "queued" as const };
    await repository.enqueueGeneration("same-request", firstJob, DEFAULT_PLANNER_REQUEST);

    const secondJob = { id: crypto.randomUUID(), planId: crypto.randomUUID(), updates: [], status: "queued" as const };
    expect((await repository.enqueueGeneration("same-request", secondJob, DEFAULT_PLANNER_REQUEST)).id).toBe(firstJob.id);
  });

  it("atomically reconciles pantry ownership with basket repricing", async () => {
    const repository = new MemoryStateRepository();
    const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
    const job = { id: crypto.randomUUID(), planId: plan.id, updates: [], status: "completed" as const };
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
});
