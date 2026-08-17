import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { generatePlan, DEFAULT_PLANNER_REQUEST } from "../domain/planner-service";
import { createMemoryState, MemoryStateRepository } from "./plan-store";

describe("state repository", () => {
  it("keeps an authoritative plan when the local repository adapter is recreated", async () => {
    const sharedState = createMemoryState();
    const firstProcess = new MemoryStateRepository(sharedState);
    const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
    const job = { id: crypto.randomUUID(), planId: plan.id, updates: [] };
    await firstProcess.createGeneration("stable-request", job, plan);

    const restartedAdapter = new MemoryStateRepository(sharedState);
    expect((await restartedAdapter.getPlan(plan.id))?.constraintsUsed).toEqual(DEFAULT_PLANNER_REQUEST);
    expect((await restartedAdapter.getJob(job.id))?.planId).toBe(plan.id);
  });

  it("returns the same generation job for a repeated idempotency key", async () => {
    const repository = new MemoryStateRepository();
    const firstPlan = await generatePlan(DEFAULT_PLANNER_REQUEST);
    const firstJob = { id: crypto.randomUUID(), planId: firstPlan.id, updates: [] };
    await repository.createGeneration("same-request", firstJob, firstPlan);

    const secondPlan = await generatePlan(DEFAULT_PLANNER_REQUEST);
    const secondJob = { id: crypto.randomUUID(), planId: secondPlan.id, updates: [] };
    expect((await repository.createGeneration("same-request", secondJob, secondPlan)).id).toBe(firstJob.id);
  });

  it("atomically reconciles pantry ownership with basket repricing", async () => {
    const repository = new MemoryStateRepository();
    const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
    const job = { id: crypto.randomUUID(), planId: plan.id, updates: [] };
    await repository.createGeneration("grocery-state", job, plan);
    const owned = new Set([
      ...plan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.id),
      plan.basket.find((item) => item.pantryStatus === "needed")!.id,
    ]);

    const updated = await repository.updateGroceryState(plan.id, new Set(), owned);
    expect(updated!.estimatedTotalCents).toBeLessThan(plan.estimatedTotalCents);
    expect(updated!.basket.find((item) => owned.has(item.id))?.pantryStatus).toBe("already_have");
  });
});
