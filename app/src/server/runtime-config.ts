import "server-only";

import { z } from "zod";

const productionSchema = z.object({
  COVE_RUNTIME_MODE: z.enum(["staging_live", "production_live"]),
  OPENAI_API_KEY: z.string().min(20),
  OPENAI_LIVE_PLANNING_ENABLED: z.literal("true"),
  DATABASE_URL: z.string().url().refine((value) => value.startsWith("postgres://") || value.startsWith("postgresql://"), "DATABASE_URL must use PostgreSQL."),
  NEXT_PUBLIC_SITE_URL: z.string().url().refine((value) => value.startsWith("https://"), "NEXT_PUBLIC_SITE_URL must use HTTPS."),
  OPENAI_PLANNER_MODEL: z.string().min(1).default("gpt-5.6-luna"),
  COVE_PLAN_RETENTION_DAYS: z.coerce.number().int().min(1).max(90).default(14),
  COVE_MODEL_TIMEOUT_MS: z.coerce.number().int().min(5_000).max(120_000).default(45_000),
  COVE_MODEL_MAX_OUTPUT_TOKENS: z.coerce.number().int().min(1_000).max(12_000).default(6_000),
  COVE_GENERATION_CONCURRENCY: z.coerce.number().int().min(1).max(20).default(3),
  COVE_LIVE_BUDGET_TARGET_PERCENT: z.coerce.number().min(0.8).max(0.98).default(0.94),
  COVE_ESTIMATE_BUDGET_TARGET_PERCENT: z.coerce.number().min(0.75).max(0.95).default(0.88),
  KROGER_CLIENT_ID: z.string().min(1).optional(),
  KROGER_CLIENT_SECRET: z.string().min(1).optional(),
}).superRefine((value, context) => {
  if (Boolean(value.KROGER_CLIENT_ID) !== Boolean(value.KROGER_CLIENT_SECRET)) {
    context.addIssue({ code: "custom", path: ["KROGER_CLIENT_ID"], message: "Kroger client ID and secret must be configured together." });
  }
});

export type ProductionConfig = z.infer<typeof productionSchema>;

export function productionConfig(): ProductionConfig {
  const parsed = productionSchema.safeParse(process.env);
  if (!parsed.success) {
    throw new ServiceConfigurationError(parsed.error.issues.map((issue) => issue.path.join(".")).join(", "));
  }
  return parsed.data;
}

export function isProductionRuntime() {
  return process.env.NODE_ENV === "production";
}

export type CoveRuntimeMode = "development_fixture" | "staging_live" | "production_live";

export function runtimeMode(): CoveRuntimeMode {
  const configured = process.env.COVE_RUNTIME_MODE;
  if (configured === "development_fixture" || configured === "staging_live" || configured === "production_live") return configured;
  return isProductionRuntime() ? "production_live" : "development_fixture";
}

function numericSetting(primary: string, legacy: string | undefined, fallback: number) {
  const value = Number(process.env[primary] ?? (legacy ? process.env[legacy] : undefined) ?? fallback);
  return Number.isFinite(value) ? value : fallback;
}

export function planRetentionDays() {
  const value = numericSetting("COVE_PLAN_RETENTION_DAYS", "WEEKTABLE_PLAN_RETENTION_DAYS", 14);
  return Number.isFinite(value) ? Math.min(90, Math.max(1, Math.trunc(value))) : 14;
}

export function modelTimeoutMs() { return Math.min(120_000, Math.max(5_000, numericSetting("COVE_MODEL_TIMEOUT_MS", "WEEKTABLE_MODEL_TIMEOUT_MS", 45_000))); }
export function modelMaxOutputTokens() { return Math.min(12_000, Math.max(1_000, numericSetting("COVE_MODEL_MAX_OUTPUT_TOKENS", "WEEKTABLE_MODEL_MAX_OUTPUT_TOKENS", 6_000))); }
export function generationConcurrency() { return Math.min(20, Math.max(1, Math.trunc(numericSetting("COVE_GENERATION_CONCURRENCY", "WEEKTABLE_GENERATION_CONCURRENCY", 3)))); }
export function budgetTargetPercent(priceKind: "live" | "feed" | "estimated" | "fixture") {
  const primary = priceKind === "estimated" ? "COVE_ESTIMATE_BUDGET_TARGET_PERCENT" : "COVE_LIVE_BUDGET_TARGET_PERCENT";
  const fallback = priceKind === "estimated" ? 0.88 : 0.94;
  return Math.min(priceKind === "estimated" ? 0.95 : 0.98, Math.max(priceKind === "estimated" ? 0.75 : 0.8, numericSetting(primary, undefined, fallback)));
}

export class ServiceConfigurationError extends Error {
  constructor(public readonly missingConfiguration: string) {
    super("Cove service configuration is incomplete.");
    this.name = "ServiceConfigurationError";
  }
}
