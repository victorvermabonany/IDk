import { PlanGenerationError } from "@/domain/types";
import { logEvent } from "@/server/observability";
import { RequestGuardError } from "@/server/request-guard";
import { ServiceConfigurationError } from "@/server/runtime-config";
import { ZodError } from "zod";

export function problemResponse(error: unknown) {
  if (error instanceof PlanGenerationError) {
    const status = error.code === "PROVIDER_UNAVAILABLE" ? 503 : error.code === "MODEL_FAILURE" ? 502 : 422;
    return Response.json({ error: { code: error.code, message: error.message, suggestions: error.suggestions } }, { status });
  }
  if (error instanceof ZodError) return Response.json({ error: { code: "INVALID_REQUEST", message: "Some planner answers are incomplete or invalid." } }, { status: 400 });
  if (error instanceof RequestGuardError) {
    const status = error.code === "RATE_LIMITED" ? 429 : error.code === "REQUEST_TOO_LARGE" ? 413 : 400;
    return Response.json({ error: { code: error.code, message: error.message, retryAfterSeconds: error.retryAfterSeconds } }, { status, headers: error.retryAfterSeconds ? { "Retry-After": String(error.retryAfterSeconds) } : undefined });
  }
  if (error instanceof ServiceConfigurationError) {
    logEvent("error", "service.configuration_invalid", { fields: error.missingConfiguration });
    return Response.json({ error: { code: "SERVICE_UNAVAILABLE", message: "Cove is temporarily unavailable. Please try again later." } }, { status: 503 });
  }
  logEvent("error", "api.unhandled_error", { category: error instanceof Error ? error.name : "UnknownError" });
  return Response.json({ error: { code: "GENERATION_FAILED", message: "We could not finish this plan. Your planner answers are still saved." } }, { status: 500 });
}

export function notFound(message: string) { return Response.json({ error: { code: "NOT_FOUND", message } }, { status: 404 }); }
