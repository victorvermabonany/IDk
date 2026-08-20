import "server-only";

import { createHash, randomUUID } from "node:crypto";
import postgres, { type Sql } from "postgres";
import { generatePlan, type GenerationProgressMetadata } from "../domain/planner-service";
import { applyPricedSwap, createSwapPreviews, reconcileGroceryOwnership, type PricedSwapPreview } from "../domain/swap-service";
import { PlanGenerationError, type MealPlan, type PlannerRequest, type SwapPreview } from "../domain/types";
import { measured } from "./observability";
import { hasActiveProEntitlement, PremiumAccessError } from "./premium-access";
import { generationConcurrency, planRetentionDays, productionConfig, runtimeMode } from "./runtime-config";

export interface GenerationUpdateRecord {
  jobId: string;
  stage: string;
  completedPlanId: string | null;
  metadata?: GenerationProgressMetadata;
  progress?: number;
}
export type GenerationJobStatus = "queued" | "running" | "completed" | "failed";
export interface JobRecord {
  id: string;
  planId: string;
  clientKey: string;
  updates: GenerationUpdateRecord[];
  status: GenerationJobStatus;
  errorCode?: string | null;
  errorMessage?: string | null;
}
export interface ClaimedGeneration { job: JobRecord; request: PlannerRequest; }

export interface StateRepository {
  getJob(id: string): Promise<JobRecord | undefined>;
  getJobByIdempotency(key: string): Promise<JobRecord | undefined>;
  getPlan(id: string): Promise<MealPlan | undefined>;
  enqueueGeneration(idempotencyKey: string, job: JobRecord, request: PlannerRequest): Promise<JobRecord>;
  claimGeneration(jobID: string): Promise<ClaimedGeneration | undefined>;
  appendGenerationUpdate(jobID: string, update: GenerationUpdateRecord): Promise<void>;
  completeGeneration(job: JobRecord, plan: MealPlan): Promise<void>;
  failGeneration(jobID: string, code: string, message: string): Promise<void>;
  savePreviews(planID: string, mealID: string, previews: PricedSwapPreview[]): Promise<void>;
  applyPreview(planID: string, mealID: string, previewID: string, clientKey: string): Promise<MealPlan | undefined>;
  updateGroceryState(planID: string, checkedItemIDs: Set<string>, ownedItemIDs: Set<string>): Promise<MealPlan | undefined>;
  ready(): Promise<void>;
}

export interface ClientAccessRecord {
  entitlementStatus: "free" | "pro" | "expired" | "revoked";
  entitlementExpiresAt?: Date | null;
  completedPlanCount: number;
  activeGenerationCount: number;
  completedSwapCount: number;
}

export interface MemoryState {
  jobs: Map<string, JobRecord>;
  plans: Map<string, MealPlan>;
  previews: Map<string, PricedSwapPreview>;
  idempotency: Map<string, string>;
  groceryCheckoffs: Map<string, Set<string>>;
  generationRequests: Map<string, PlannerRequest>;
  generationLeases: Map<string, number>;
  clientAccess: Map<string, ClientAccessRecord>;
  planOwners: Map<string, string>;
}

export function createMemoryState(): MemoryState {
  return {
    jobs: new Map(), plans: new Map(), previews: new Map(), idempotency: new Map(), groceryCheckoffs: new Map(),
    generationRequests: new Map(), generationLeases: new Map(), clientAccess: new Map(), planOwners: new Map(),
  };
}

function defaultClientAccess(): ClientAccessRecord {
  return { entitlementStatus: "free", completedPlanCount: 0, activeGenerationCount: 0, completedSwapCount: 0 };
}

function isProAccess(access: ClientAccessRecord) {
  return hasActiveProEntitlement(access.entitlementStatus, access.entitlementExpiresAt);
}

function hashKey(value: string) { return createHash("sha256").update(value).digest("hex"); }

export class MemoryStateRepository implements StateRepository {
  constructor(private readonly state: MemoryState = createMemoryState()) {}
  async getJob(id: string) { return this.state.jobs.get(id); }
  async getJobByIdempotency(key: string) { const id = this.state.idempotency.get(hashKey(key)); return id ? this.state.jobs.get(id) : undefined; }
  async getPlan(id: string) { return this.state.plans.get(id); }
  async enqueueGeneration(key: string, job: JobRecord, request: PlannerRequest) {
    const existing = await this.getJobByIdempotency(key); if (existing) return existing;
    const access = this.state.clientAccess.get(job.clientKey) ?? defaultClientAccess();
    if (!isProAccess(access) && access.completedPlanCount + access.activeGenerationCount >= 1) {
      throw new PremiumAccessError("another_week");
    }
    access.activeGenerationCount += 1;
    this.state.clientAccess.set(job.clientKey, access);
    this.state.jobs.set(job.id, structuredClone(job));
    this.state.generationRequests.set(job.id, structuredClone(request));
    this.state.idempotency.set(hashKey(key), job.id);
    return job;
  }
  async claimGeneration(jobID: string) {
    const job = this.state.jobs.get(jobID);
    const request = this.state.generationRequests.get(jobID);
    const lease = this.state.generationLeases.get(jobID) ?? 0;
    if (!job || !request || job.status === "completed" || job.status === "failed") return undefined;
    if (job.status === "running" && lease > Date.now()) return undefined;
    job.status = "running";
    this.state.generationLeases.set(jobID, Date.now() + 120_000);
    return { job: structuredClone(job), request: structuredClone(request) };
  }
  async appendGenerationUpdate(jobID: string, update: GenerationUpdateRecord) {
    const job = this.state.jobs.get(jobID);
    if (!job || job.status !== "running") return;
    const latest = job.updates.at(-1);
    if (latest?.stage === update.stage) job.updates[job.updates.length - 1] = structuredClone(update);
    else job.updates.push(structuredClone(update));
  }
  async completeGeneration(job: JobRecord, plan: MealPlan) {
    this.state.plans.set(plan.id, structuredClone(plan));
    this.state.planOwners.set(plan.id, job.clientKey);
    this.state.jobs.set(job.id, structuredClone(job));
    this.state.generationLeases.delete(job.id);
    const access = this.state.clientAccess.get(job.clientKey) ?? defaultClientAccess();
    access.activeGenerationCount = Math.max(0, access.activeGenerationCount - 1);
    access.completedPlanCount += 1;
    this.state.clientAccess.set(job.clientKey, access);
  }
  async failGeneration(jobID: string, code: string, message: string) {
    const job = this.state.jobs.get(jobID);
    if (!job) return;
    job.status = "failed";
    job.errorCode = code;
    job.errorMessage = message;
    this.state.generationLeases.delete(jobID);
    const access = this.state.clientAccess.get(job.clientKey) ?? defaultClientAccess();
    access.activeGenerationCount = Math.max(0, access.activeGenerationCount - 1);
    this.state.clientAccess.set(job.clientKey, access);
  }
  async savePreviews(_planID: string, _mealID: string, previews: PricedSwapPreview[]) { previews.forEach((preview) => this.state.previews.set(preview.id, structuredClone(preview))); }
  async applyPreview(planID: string, mealID: string, previewID: string, clientKey: string) {
    const plan = this.state.plans.get(planID); const preview = this.state.previews.get(previewID);
    if (!plan || !preview) return undefined;
    const owner = this.state.planOwners.get(planID);
    if (owner && owner !== clientKey) return undefined;
    if (!owner) this.state.planOwners.set(planID, clientKey);
    const access = this.state.clientAccess.get(clientKey) ?? defaultClientAccess();
    if (!isProAccess(access) && access.completedSwapCount >= 1) throw new PremiumAccessError("additional_swap");
    const updated = applyPricedSwap(plan, mealID, preview);
    this.state.plans.set(planID, structuredClone(updated));
    this.state.previews.clear();
    access.completedSwapCount += 1;
    this.state.clientAccess.set(clientKey, access);
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
    await this.sql`SELECT 1 FROM cove_schema_migrations LIMIT 1`;
    await this.sql`SELECT 1 FROM weektable_plans LIMIT 1`;
    await this.sql`DELETE FROM weektable_plans WHERE expires_at < now()`;
  }

  async getJob(id: string) {
    await this.ready();
    const rows = await this.sql<{ id: string; plan_id: string; client_key: string | null; updates: GenerationUpdateRecord[]; status: GenerationJobStatus; error_code: string | null; error_message: string | null }[]>`
      SELECT id, plan_id, client_key, updates, status, error_code, error_message
      FROM weektable_generation_jobs WHERE id = ${id} AND expires_at > now()`;
    return rows[0] ? { id: rows[0].id, planId: rows[0].plan_id, clientKey: rows[0].client_key ?? hashKey(rows[0].id), updates: rows[0].updates, status: rows[0].status, errorCode: rows[0].error_code, errorMessage: rows[0].error_message } : undefined;
  }
  async getJobByIdempotency(key: string) {
    await this.ready();
    const rows = await this.sql<{ id: string; plan_id: string; client_key: string | null; updates: GenerationUpdateRecord[]; status: GenerationJobStatus; error_code: string | null; error_message: string | null }[]>`
      SELECT jobs.id, jobs.plan_id, jobs.client_key, jobs.updates, jobs.status, jobs.error_code, jobs.error_message FROM weektable_idempotency_keys keys
      JOIN weektable_generation_jobs jobs ON jobs.id = keys.job_id
      WHERE keys.key_hash = ${hashKey(key)} AND keys.expires_at > now()`;
    return rows[0] ? { id: rows[0].id, planId: rows[0].plan_id, clientKey: rows[0].client_key ?? hashKey(rows[0].id), updates: rows[0].updates, status: rows[0].status, errorCode: rows[0].error_code, errorMessage: rows[0].error_message } : undefined;
  }
  async getPlan(id: string) {
    await this.ready();
    const rows = await this.sql<{ snapshot: MealPlan }[]>`SELECT snapshot FROM weektable_plans WHERE id = ${id} AND expires_at > now()`;
    return rows[0]?.snapshot;
  }
  async enqueueGeneration(key: string, job: JobRecord, request: PlannerRequest) {
    await this.ready();
    return this.sql.begin(async (tx) => {
      await tx`SELECT pg_advisory_xact_lock(hashtext(${hashKey(key)}))`;
      const existing = await tx<{ id: string; plan_id: string; client_key: string | null; updates: GenerationUpdateRecord[]; status: GenerationJobStatus; error_code: string | null; error_message: string | null }[]>`
        SELECT jobs.id, jobs.plan_id, jobs.client_key, jobs.updates, jobs.status, jobs.error_code, jobs.error_message FROM weektable_idempotency_keys keys JOIN weektable_generation_jobs jobs ON jobs.id = keys.job_id
        WHERE keys.key_hash = ${hashKey(key)} AND keys.expires_at > now() FOR UPDATE`;
      if (existing[0]) return { id: existing[0].id, planId: existing[0].plan_id, clientKey: existing[0].client_key ?? hashKey(existing[0].id), updates: existing[0].updates, status: existing[0].status, errorCode: existing[0].error_code, errorMessage: existing[0].error_message };
      await tx`INSERT INTO weektable_client_access (client_key) VALUES (${job.clientKey}) ON CONFLICT (client_key) DO NOTHING`;
      const access = await tx<{ entitlement_status: string; entitlement_expires_at: Date | null; completed_plan_count: number; active_generation_count: number }[]>`
        SELECT entitlement_status, entitlement_expires_at, completed_plan_count, active_generation_count
        FROM weektable_client_access WHERE client_key = ${job.clientKey} FOR UPDATE`;
      const row = access[0];
      const activeJobs = await tx<{ count: number }[]>`
        SELECT count(*)::int AS count FROM weektable_generation_jobs
        WHERE client_key = ${job.clientKey} AND status IN ('queued', 'running') AND expires_at > now()`;
      row.active_generation_count = activeJobs[0]?.count ?? 0;
      await tx`UPDATE weektable_client_access SET active_generation_count = ${row.active_generation_count}, updated_at = now() WHERE client_key = ${job.clientKey}`;
      if (!hasActiveProEntitlement(row.entitlement_status, row.entitlement_expires_at)
        && row.completed_plan_count + row.active_generation_count >= 1) {
        throw new PremiumAccessError("another_week");
      }
      await tx`UPDATE weektable_client_access SET active_generation_count = active_generation_count + 1, updated_at = now() WHERE client_key = ${job.clientKey}`;
      const expiry = this.expiry();
      await tx`INSERT INTO weektable_generation_jobs (id, plan_id, client_key, updates, request_snapshot, status, expires_at)
        VALUES (${job.id}, ${job.planId}, ${job.clientKey}, ${tx.json(JSON.parse(JSON.stringify(job.updates)))}, ${tx.json(JSON.parse(JSON.stringify(request)))}, ${job.status}, ${expiry})`;
      await tx`INSERT INTO weektable_idempotency_keys (key_hash, job_id, expires_at) VALUES (${hashKey(key)}, ${job.id}, ${expiry})`;
      return job;
    });
  }
  async claimGeneration(jobID: string) {
    await this.ready();
    const rows = await this.sql<{ id: string; plan_id: string; client_key: string | null; updates: GenerationUpdateRecord[]; request_snapshot: PlannerRequest; status: GenerationJobStatus }[]>`
      UPDATE weektable_generation_jobs
      SET status = 'running', lease_expires_at = now() + interval '2 minutes', error_code = NULL, error_message = NULL
      WHERE id = ${jobID} AND expires_at > now()
        AND (status = 'queued' OR (status = 'running' AND lease_expires_at < now()))
      RETURNING id, plan_id, client_key, updates, request_snapshot, status`;
    const row = rows[0];
    return row ? { job: { id: row.id, planId: row.plan_id, clientKey: row.client_key ?? hashKey(row.id), updates: row.updates, status: row.status }, request: row.request_snapshot } : undefined;
  }
  async appendGenerationUpdate(jobID: string, update: GenerationUpdateRecord) {
    await this.ready();
    await this.sql`
      UPDATE weektable_generation_jobs
      SET updates = CASE
        WHEN updates->-1->>'stage' = ${update.stage}
          THEN (updates - (jsonb_array_length(updates) - 1)) || ${this.sql.json(JSON.parse(JSON.stringify(update)))}::jsonb
        ELSE updates || ${this.sql.json(JSON.parse(JSON.stringify(update)))}::jsonb
      END
      WHERE id = ${jobID} AND status = 'running' AND expires_at > now()`;
  }
  async completeGeneration(job: JobRecord, plan: MealPlan) {
    await this.ready();
    const expiry = this.expiry();
    await this.sql.begin(async (tx) => {
      await tx`INSERT INTO weektable_plans (id, client_key, snapshot, constraints_snapshot, pricing_provenance, model_metadata, expires_at)
        VALUES (${plan.id}, ${job.clientKey}, ${tx.json(JSON.parse(JSON.stringify(plan)))}, ${tx.json(JSON.parse(JSON.stringify(plan.constraintsUsed)))}, ${tx.json(JSON.parse(JSON.stringify(plan.pricingProvenance)))}, ${tx.json({ model: process.env.OPENAI_PLANNER_MODEL ?? "gpt-5.6-luna", liveGeneration: process.env.OPENAI_LIVE_PLANNING_ENABLED === "true", generatedAt: plan.createdAt })}, ${expiry})
        ON CONFLICT (id) DO UPDATE SET client_key = excluded.client_key, snapshot = excluded.snapshot, constraints_snapshot = excluded.constraints_snapshot, pricing_provenance = excluded.pricing_provenance, model_metadata = excluded.model_metadata, expires_at = excluded.expires_at`;
      await tx`UPDATE weektable_generation_jobs
        SET updates = ${tx.json(JSON.parse(JSON.stringify(job.updates)))}, status = 'completed', lease_expires_at = NULL, error_code = NULL, error_message = NULL
        WHERE id = ${job.id}`;
      await tx`UPDATE weektable_client_access
        SET active_generation_count = greatest(0, active_generation_count - 1), completed_plan_count = completed_plan_count + 1, updated_at = now()
        WHERE client_key = ${job.clientKey}`;
    });
  }
  async failGeneration(jobID: string, code: string, message: string) {
    await this.ready();
    await this.sql.begin(async (tx) => {
      const jobs = await tx<{ client_key: string | null; status: GenerationJobStatus }[]>`
        SELECT client_key, status FROM weektable_generation_jobs WHERE id = ${jobID} FOR UPDATE`;
      await tx`UPDATE weektable_generation_jobs
        SET status = 'failed', lease_expires_at = NULL, error_code = ${code}, error_message = ${message}
        WHERE id = ${jobID}`;
      const job = jobs[0];
      if (job?.client_key && job.status !== "failed") {
        await tx`UPDATE weektable_client_access
          SET active_generation_count = greatest(0, active_generation_count - 1), updated_at = now()
          WHERE client_key = ${job.client_key}`;
      }
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
  async applyPreview(planID: string, mealID: string, previewID: string, clientKey: string) {
    await this.ready();
    return this.sql.begin(async (tx) => {
      const plans = await tx<{ snapshot: MealPlan; client_key: string | null }[]>`SELECT snapshot, client_key FROM weektable_plans WHERE id = ${planID} AND expires_at > now() FOR UPDATE`;
      const previews = await tx<{ snapshot: PricedSwapPreview }[]>`SELECT snapshot FROM weektable_swap_previews WHERE id = ${previewID} AND plan_id = ${planID} AND meal_id = ${mealID} AND expires_at > now()`;
      if (!plans[0] || !previews[0]) return undefined;
      if (plans[0].client_key && plans[0].client_key !== clientKey) return undefined;
      await tx`INSERT INTO weektable_client_access (client_key) VALUES (${clientKey}) ON CONFLICT (client_key) DO NOTHING`;
      const access = await tx<{ entitlement_status: string; entitlement_expires_at: Date | null; completed_swap_count: number }[]>`
        SELECT entitlement_status, entitlement_expires_at, completed_swap_count FROM weektable_client_access WHERE client_key = ${clientKey} FOR UPDATE`;
      if (!hasActiveProEntitlement(access[0].entitlement_status, access[0].entitlement_expires_at) && access[0].completed_swap_count >= 1) {
        throw new PremiumAccessError("additional_swap");
      }
      const updated = applyPricedSwap(plans[0].snapshot, mealID, previews[0].snapshot);
      await tx`UPDATE weektable_plans SET client_key = ${clientKey}, snapshot = ${tx.json(JSON.parse(JSON.stringify(updated)))} WHERE id = ${planID}`;
      await tx`DELETE FROM weektable_swap_previews WHERE plan_id = ${planID}`;
      await tx`UPDATE weektable_client_access SET completed_swap_count = completed_swap_count + 1, updated_at = now() WHERE client_key = ${clientKey}`;
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

const stages = ["Planning your meals", "Building your grocery list", "Checking your store", "Balancing your budget", "Finishing your week"];
let activeGenerations = 0;
let repositoryOverride: StateRepository | undefined;
let productionRepository: StateRepository | undefined;
const developmentGlobal = globalThis as typeof globalThis & { __coveDevelopmentRepository?: MemoryStateRepository };
const developmentRepository = developmentGlobal.__coveDevelopmentRepository ??= new MemoryStateRepository();

function repository(): StateRepository {
  if (repositoryOverride) return repositoryOverride;
  if (runtimeMode() === "development_fixture") return developmentRepository;
  if (!productionRepository) {
    const config = productionConfig();
    productionRepository = new PostgresStateRepository(postgres(config.DATABASE_URL, { max: 10, idle_timeout: 20, connect_timeout: 10 }));
  }
  return productionRepository;
}

export function useStateRepositoryForTests(value?: StateRepository) { repositoryOverride = value; }

export async function startGeneration(request: PlannerRequest, idempotencyKey: string, clientKey: string) {
  const store = repository();
  const existing = await store.getJobByIdempotency(idempotencyKey); if (existing) return existing;
  const jobID = randomUUID();
  const job: JobRecord = {
    id: jobID,
    planId: randomUUID(),
    clientKey,
    status: "queued",
    updates: [{ jobId: jobID, stage: stages[0], completedPlanId: null }],
  };
  return store.enqueueGeneration(idempotencyKey, job, request);
}

export async function runGeneration(jobID: string) {
  if (activeGenerations >= generationConcurrency()) return;
  const store = repository();
  const claimed = await store.claimGeneration(jobID);
  if (!claimed) return;
  activeGenerations += 1;
  try {
    await measured("plan.generation", async () => {
      const plan = await generatePlan(claimed.request, claimed.job.planId, async (event) => {
        await store.appendGenerationUpdate(jobID, {
          jobId: claimed.job.id,
          stage: event.stage,
          completedPlanId: null,
          metadata: event.metadata,
        });
      });
      const latest = await store.getJob(jobID);
      const completed: JobRecord = {
        ...claimed.job,
        status: "completed",
        updates: (latest?.updates ?? claimed.job.updates).map((update, index, updates) => ({
          ...update,
          completedPlanId: index === updates.length - 1 ? plan.id : null,
        })),
      };
      await store.completeGeneration(completed, plan);
    });
  } catch (error) {
    const known = error instanceof PlanGenerationError;
    await store.failGeneration(
      jobID,
      known ? error.code : "GENERATION_FAILED",
      known ? error.message : "Cove could not finish this plan. Your planner answers are saved.",
    );
  } finally {
    activeGenerations -= 1;
  }
}

export async function readJob(jobID: string) { return repository().getJob(jobID); }
export async function readPlan(planID: string) { return repository().getPlan(planID); }
export async function previewsFor(planID: string, mealID: string): Promise<SwapPreview[]> {
  const store = repository(); const plan = await store.getPlan(planID); if (!plan) return [];
  const previews = await createSwapPreviews(plan, mealID); await store.savePreviews(planID, mealID, previews);
  return previews.map(({ id, meal, deltaCents, reusedIngredientCount, resultingTotalCents }) => ({ id, meal, deltaCents, reusedIngredientCount, resultingTotalCents }));
}
export async function applyPreview(planID: string, mealID: string, previewID: string, clientKey: string) { return repository().applyPreview(planID, mealID, previewID, clientKey); }
export async function updateGroceryState(planID: string, checked: Set<string>, owned: Set<string>) { return repository().updateGroceryState(planID, checked, owned); }
export async function databaseReady() { await repository().ready(); }
