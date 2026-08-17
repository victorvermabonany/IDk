import "server-only";

export type LogLevel = "info" | "warn" | "error";

const sensitiveKeys = new Set(["postalcode", "allergies", "dietaryrestrictions", "dislikedfoods", "preferredcuisines", "pantryitems", "custominstructions", "authorization", "openai_api_key"]);

function sanitize(value: unknown): unknown {
  if (Array.isArray(value)) return { count: value.length };
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, sensitiveKeys.has(key.toLowerCase()) ? "[redacted]" : sanitize(item)]));
}

export function logEvent(level: LogLevel, event: string, fields: Record<string, unknown> = {}) {
  const safeFields = sanitize(fields) as Record<string, unknown>;
  const record = JSON.stringify({ timestamp: new Date().toISOString(), level, event, ...safeFields });
  if (level === "error") console.error(record);
  else if (level === "warn") console.warn(record);
  else console.info(record);
}

export async function measured<T>(event: string, work: () => Promise<T>): Promise<T> {
  const started = performance.now();
  try {
    const result = await work();
    logEvent("info", event, { outcome: "success", durationMs: Math.round(performance.now() - started) });
    return result;
  } catch (error) {
    logEvent("error", event, { outcome: "failure", durationMs: Math.round(performance.now() - started), category: error instanceof Error ? error.name : "UnknownError" });
    throw error;
  }
}
