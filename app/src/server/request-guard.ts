import "server-only";

import { createHash } from "node:crypto";

const buckets = new Map<string, { count: number; resetAt: number }>();
const MAX_BODY_BYTES = 24_000;

export class RequestGuardError extends Error {
  constructor(public readonly code: "INVALID_REQUEST" | "REQUEST_TOO_LARGE" | "RATE_LIMITED", message: string, public readonly retryAfterSeconds?: number) {
    super(message);
    this.name = "RequestGuardError";
  }
}

export async function readJSONBody(request: Request): Promise<unknown> {
  const body = await request.text();
  if (new TextEncoder().encode(body).byteLength > MAX_BODY_BYTES) throw new RequestGuardError("REQUEST_TOO_LARGE", "That request is too large.");
  try { return JSON.parse(body) as unknown; }
  catch { throw new RequestGuardError("INVALID_REQUEST", "The request body is not valid JSON."); }
}

export function clientIdentifier(request: Request) {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const device = (request.headers.get("x-cove-device-id") ?? request.headers.get("x-weektable-device-id"))?.slice(0, 128);
  return createHash("sha256").update(device || forwarded || "anonymous").digest("hex").slice(0, 24);
}

export function guardRequest(request: Request, limit = 30, windowMs = 60_000) {
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > MAX_BODY_BYTES) throw new RequestGuardError("REQUEST_TOO_LARGE", "That request is too large.");

  const now = Date.now();
  const key = clientIdentifier(request);
  const current = buckets.get(key);
  if (!current || current.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return;
  }
  current.count += 1;
  if (current.count > limit) {
    throw new RequestGuardError("RATE_LIMITED", "Too many requests. Please wait a moment and try again.", Math.max(1, Math.ceil((current.resetAt - now) / 1_000)));
  }
  if (buckets.size > 10_000) {
    for (const [bucketKey, bucket] of buckets) if (bucket.resetAt <= now) buckets.delete(bucketKey);
  }
}
