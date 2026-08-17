import "server-only";

import { z } from "zod";

const productionSchema = z.object({
  OPENAI_API_KEY: z.string().min(20),
  OPENAI_LIVE_PLANNING_ENABLED: z.literal("true"),
  DATABASE_URL: z.string().url().refine((value) => value.startsWith("postgres://") || value.startsWith("postgresql://"), "DATABASE_URL must use PostgreSQL."),
  OPENAI_PLANNER_MODEL: z.string().min(1).default("gpt-5.6-luna"),
  WEEKTABLE_PLAN_RETENTION_DAYS: z.coerce.number().int().min(1).max(90).default(14),
  WEEKTABLE_MODEL_TIMEOUT_MS: z.coerce.number().int().min(5_000).max(120_000).default(45_000),
  WEEKTABLE_MODEL_MAX_OUTPUT_TOKENS: z.coerce.number().int().min(1_000).max(12_000).default(6_000),
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

export function planRetentionDays() {
  const value = Number(process.env.WEEKTABLE_PLAN_RETENTION_DAYS ?? 14);
  return Number.isFinite(value) ? Math.min(90, Math.max(1, Math.trunc(value))) : 14;
}

export class ServiceConfigurationError extends Error {
  constructor(public readonly missingConfiguration: string) {
    super("Weektable service configuration is incomplete.");
    this.name = "ServiceConfigurationError";
  }
}
