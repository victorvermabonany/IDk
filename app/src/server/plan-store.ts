import "server-only";

import { createHash, randomUUID } from "node:crypto";
import postgres, { type Sql } from "postgres";
import { generatePlan } from "../domain/planner-service";
import { applyPricedSwap, createSwapPreviews, reconcileGroceryOwnership, type PricedSwapPreview } from "../domain/swap-service";
import { PlanGenerationError, type MealPlan, type PlannerRequest, type SwapPreview } from "../domain/types";
import { measured } from "./observability";
import { isProductionRuntime, planRetentionDays, productionConfig } from "./runtime-config";

export interface GenerationUpdateRecord { jobId: string; stage: string; progress: number; completedPlanId: string | null; }
export interface JobRecord { id: string; planId: string; updates: GenerationUpdateRecord[]; }

export interface StateRepository {
  getJob(id: string): Promise<JobRecord | undefined>;
  getJobByIdempotency(key: string): Promise<JobRecord | undefined>;
  getPlan(id: string): Promise<MealPlan | undefined>;
  createGeneration(idempotencyKey: string, job: JobRecord, plan: MealPlan): Promise<JobRecord>;
  savePreviews(planID: string, mealID: string, previews: PricedSwapPreview[]): Promise<void>;
  applyPreview(planID: string, mealID: string, previewID: string): Promise<MealPlan | undefined>;
  updateGroceryState(planID: string, checkedItemIDs: Set<string>, ownedItemIDs: Set<string>): Promise<MealPlan | undefined>;
  ready(): Promise<void>;
}

export interface MemoryState {
  jobs: Map<string, JobRecord>;
  plans: Map<string, MealPlan>;
  previews: Map<string, PricedSwapPreview>;
  idempotency: Map<string, string>;
  groceryCheckoffs: Map<string, Set<string>>;
}

export function createMemoryState(): MemoryState {
  return { jobs: new Map(), plans: new Map(), previews: new Map(), idempotency: new Map(), groceryCheckoffs: new Map() };
}

function hashKey(value: string) { return createHash("sha256").update(value).digest("hex"); }

export class MemoryStateRepository implements StateRepository {
  constructor(private readonly state: MemoryState = createMemoryState()) {}
  async getJob(id: string) { return this.state.jobs.get(id); }
  async getJobByIdempotency(key: string) { const id = this.state.idempotency.get(hashKey(key)); return id ? this.state.jobs.get(id) : undefined; }
  async getPlan(id: string) { return this.state.plans.get(id); }
  async createGeneration(key: string, job: JobRecord, plan: MealPlan) {
    const existing = await this.getJobByIdempotency(key); if (existing) return existing;
    this.state.plans.set(plan.id, structuredClone(plan));
    this.state.jobs.set(job.id, structuredClone(job));
    this.state.idempotency.set(hashKey(key), job.id);
    return job;
  }
  async savePreviews(_planID: string, _mealID: string, previews: PricedSwapPreview[]) { previews.forEach((preview) => this.state.previews.set(preview.id, structuredClone(preview))); }
  async applyPreview(planID: string, mealID: string, previewID: string) {
    const plan = this.state.plans.get(planID); const preview = this.state.previews.get(previewID);
    if (!plan || !preview) return undefined;
    const updated = applyPricedSwap(plan, mealID, preview);
    this.state.plans.set(planID, structuredClone(updated));
    this.state.previews.clear();
    return updated;
  }
  async updateGroceryState(planID: string, checked: Set<string>, owned: Set<string>) {
    const plan = this.state.plans.get(planID); if (!plan) return undefined;
    const updated = reconcileGroceryOwnership(plan, owned);
    this.state.plans.set(planID, structuredClone(updated));
    this.state.groceryCheckoffs.set(planID, new Set(checked));
    return updated;
  }
  async ready() {}
}

export class PostgresStateRepository implements StateRepository {
  private initialized?: Promise<void>;
  constructor(private readonly sql: Sql) {}

  ready() { this.initialized ??= this.initialize(); return this.initialized; }
  private expiry() { return new Date(Date.now() + planRetentionDays() * 86_400_000); }

  private async initialize() {
    await this.sql.unsafe(`
      CREATE TABLE IF NOT EXISTS weektable_plans (id text PRIMARY KEY, snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL);
      CREATE TABLE IF NOT EXISTS weektable_generation_jobs (id text PRIMARY KEY, plan_id text NOT NULL REFERENCES weektable_plans(id) ON DELETE CASCADE, updates jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL);
      CREATE TABLE IF NOT EXISTS weektable_idempotency_keys (key_hash text PRIMARY KEY, job_id text NOT NULL REFERENCES weektable_generation_jobs(id) ON DELETE CASCADE, expires_at timestamptz NOT NULL);
      CREATE TABLE IF NOT EXISTS weektable_swap_previews (id text PRIMARY KEY, plan_id text NOT NULL REFERENCES weektable_plans(id) ON DELETE CASCADE, meal_id text NOT NULL, snapshot jsonb NOT NULL, expires_at timestamptz NOT NULL);
      CREATE TABLE IF NOT EXISTS weektable_grocery_state (plan_id text PRIMARY KEY REFERENCES weektable_plans(id) ON DELETE CASCADE, checked_item_ids jsonb NOT NULL DEFAULT '[]'::jsonb, owned_item_ids jsonb NOT NULL DEFAULT '[]'::jsonb, updated_at timestamptz NOT NULL DEFAULT now());
      CREATE INDEX IF NOT EXISTS weektable_plans_expires_at_idx ON weektable_plans(expires_at);
    `);
    await this.sql`DELETE FROM weektable_plans WHERE expires_at < now()`;
  }

  async getJob(id: string) {
    await this.ready();
    const rows = await this.sql<{ id: string; plan_id: string; updates: GenerationUpdateRecord[] }[]>`SELECT id, plan_id, updates FROM weektable_generation_jobs WHERE id = ${id} AND expires_at > now()`;
    return rows[0] ? { id: rows[0].id, planId: rows[0].plan_id, updates: rows[0].updates } : undefined;
  }
  async getJobByIdempotency(key: string) {
    await this.ready();
    const rows = await this.sql<{ id: string; plan_id: string; updates: GenerationUpdateRecord[] }[]>`
      SELECT jobs.id, jobs.plan_id, jobs.updates FROM weektable_idempotency_keys keys
      JOIN weektable_generation_jobs jobs ON jobs.id = keys.job_id
      WHERE keys.key_hash = ${hashKey(key)} AND keys.expires_at > now()`;
    return rows[0] ? { id: rows[0].id, planId: rows[0].plan_id, updates: rows[0].updates } : undefined;
  }
  async getPlan(id: string) {
    await this.ready();
    const rows = await this.sql<{ snapshot: MealPlan }[]>`SELECT snapshot FROM weektable_plans WHERE id = ${id} AND expires_at > now()`;
    return rows[0]?.snapshot;
  }
  async createGeneration(key: string, job: JobRecord, plan: MealPlan) {
    await this.ready();
    return this.sql.begin(async (tx) => {
      await tx`SELECT pg_advisory_xact_lock(hashtext(${hashKey(key)}))`;
      const existing = await tx<{ id: string; plan_id: string; updates: GenerationUpdateRecord[] }[]>`
        SELECT jobs.id, jobs.plan_id, jobs.updates FROM weektable_idempotency_keys keys JOIN weektable_generation_jobs jobs ON jobs.id = keys.job_id
        WHERE keys.key_hash = ${hashKey(key)} AND keys.expires_at > now() FOR UPDATE`;
      if (existing[0]) return { id: existing[0].id, planId: existing[0].plan_id, updates: existing[0].updates };
      const expiry = this.expiry();
      await tx`INSERT INTO weektable_plans (id, snapshot, expires_at) VALUES (${plan.id}, ${tx.json(JSON.parse(JSON.stringify(plan)))}, ${expiry})`;
      await tx`INSERT INTO weektable_generation_jobs (id, plan_id, updates, expires_at) VALUES (${job.id}, ${job.planId}, ${tx.json(JSON.parse(JSON.stringify(job.updates)))}, ${expiry})`;
      await tx`INSERT INTO weektable_idempotency_keys (key_hash, job_id, expires_at) VALUES (${hashKey(key)}, ${job.id}, ${expiry})`;
      return job;
    });
  }
  async savePreviews(planID: string, mealID: string, previews: PricedSwapPreview[]) {
    await this.ready(); const expiry = this.expiry();
    await this.sql.begin(async (tx) => {
      for (const preview of previews) await tx`INSERT INTO weektable_swap_previews (id, plan_id, meal_id, snapshot, expires_at)
        VALUES (${preview.id}, ${planID}, ${mealID}, ${tx.json(JSON.parse(JSON.stringify(preview)))}, ${expiry})
        ON CONFLICT (id) DO UPDATE SET snapshot = excluded.snapshot, expires_at = excluded.expires_at`;
    });
  }
  async applyPreview(planID: string, mealID: string, previewID: string) {
    await this.ready();
    return this.sql.begin(async (tx) => {
      const plans = await tx<{ snapshot: MealPlan }[]>`SELECT snapshot FROM weektable_plans WHERE id = ${planID} AND expires_at > now() FOR UPDATE`;
      const previews = await tx<{ snapshot: PricedSwapPreview }[]>`SELECT snapshot FROM weektable_swap_previews WHERE id = ${previewID} AND plan_id = ${planID} AND meal_id = ${mealID} AND expires_at > now()`;
      if (!plans[0] || !previews[0]) return undefined;
      const updated = applyPricedSwap(plans[0].snapshot, mealID, previews[0].snapshot);
      await tx`UPDATE weektable_plans SET snapshot = ${tx.json(JSON.parse(JSON.stringify(updated)))} WHERE id = ${planID}`;
      await tx`DELETE FROM weektable_swap_previews WHERE plan_id = ${planID}`;
      return updated;
    });
  }
  async updateGroceryState(planID: string, checked: Set<string>, owned: Set<string>) {
    await this.ready();
    return this.sql.begin(async (tx) => {
      const plans = await tx<{ snapshot: MealPlan }[]>`SELECT snapshot FROM weektable_plans WHERE id = ${planID} AND expires_at > now() FOR UPDATE`;
      if (!plans[0]) return undefined;
      const updated = reconcileGroceryOwnership(plans[0].snapshot, owned);
      await tx`UPDATE weektable_plans SET snapshot = ${tx.json(JSON.parse(JSON.stringify(updated)))} WHERE id = ${planID}`;
      await tx`INSERT INTO weektable_grocery_state (plan_id, checked_item_ids, owned_item_ids, updated_at)
        VALUES (${planID}, ${tx.json([...checked])}, ${tx.json([...owned])}, now())
        ON CONFLICT (plan_id) DO UPDATE SET checked_item_ids = excluded.checked_item_ids, owned_item_ids = excluded.owned_item_ids, updated_at = now()`;
      return updated;
    });
  }
}

const stages = ["Planning your meals", "Combining ingredients", "Checking complete packages", "Balancing your budget", "Finalizing your week"];
let activeGenerations = 0;
let repositoryOverride: StateRepository | undefined;
let productionRepository: StateRepository | undefined;
const developmentRepository = new MemoryStateRepository();

function repository(): StateRepository {
  if (repositoryOverride) return repositoryOverride;
  if (!isProductionRuntime()) return developmentRepository;
  if (!productionRepository) {
    const config = productionConfig();
    productionRepository = new PostgresStateRepository(postgres(config.DATABASE_URL, { max: 10, idle_timeout: 20, connect_timeout: 10 }));
  }
  return productionRepository;
}

export function useStateRepositoryForTests(value?: StateRepository) { repositoryOverride = value; }

export async function startGeneration(request: PlannerRequest, idempotencyKey: string) {
  return measured("plan.generation", async () => {
    const store = repository();
    const existing = await store.getJobByIdempotency(idempotencyKey); if (existing) return existing;
    const maximumConcurrent = Math.min(20, Math.max(1, Number(process.env.WEEKTABLE_GENERATION_CONCURRENCY ?? 3)));
    if (activeGenerations >= maximumConcurrent) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Weektable is handling several plans right now. Please try again shortly.");
    activeGenerations += 1;
    try {
      const plan = await generatePlan(request);
      const jobID = randomUUID();
      const updates = stages.map((stage, index) => ({ jobId: jobID, stage, progress: (index + 1) / stages.length, completedPlanId: index === stages.length - 1 ? plan.id : null }));
      return await store.createGeneration(idempotencyKey, { id: jobID, planId: plan.id, updates }, plan);
    } finally { activeGenerations -= 1; }
  });
}

export async function readJob(jobID: string) { return repository().getJob(jobID); }
export async function readPlan(planID: string) { return repository().getPlan(planID); }
export async function previewsFor(planID: string, mealID: string): Promise<SwapPreview[]> {
  const store = repository(); const plan = await store.getPlan(planID); if (!plan) return [];
  const previews = await createSwapPreviews(plan, mealID); await store.savePreviews(planID, mealID, previews);
  return previews.map(({ id, meal, deltaCents, reusedIngredientCount, resultingTotalCents }) => ({ id, meal, deltaCents, reusedIngredientCount, resultingTotalCents }));
}
export async function applyPreview(planID: string, mealID: string, previewID: string) { return repository().applyPreview(planID, mealID, previewID); }
export async function updateGroceryState(planID: string, checked: Set<string>, owned: Set<string>) { return repository().updateGroceryState(planID, checked, owned); }
export async function databaseReady() { await repository().ready(); }
