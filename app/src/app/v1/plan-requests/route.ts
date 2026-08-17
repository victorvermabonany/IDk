import { plannerRequestSchema } from "@/domain/types";
import { problemResponse } from "@/server/http";
import { startGeneration } from "@/server/plan-store";
import { guardRequest, readJSONBody } from "@/server/request-guard";

export async function POST(request: Request) {
  try {
    guardRequest(request, 6, 60_000);
    const key = request.headers.get("Idempotency-Key") ?? crypto.randomUUID();
    if (key.length > 200) return Response.json({ error: { code: "INVALID_IDEMPOTENCY_KEY", message: "The request identifier is invalid." } }, { status: 400 });
    const input = plannerRequestSchema.parse(await readJSONBody(request));
    const job = await startGeneration(input, key);
    return Response.json({ job: { id: job.id, planId: job.planId } }, { status: 202 });
  } catch (error) { return problemResponse(error); }
}
