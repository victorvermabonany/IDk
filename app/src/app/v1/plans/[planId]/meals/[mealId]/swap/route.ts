import { z } from "zod";
import { apiPlan } from "@/server/api-dto";
import { notFound, problemResponse } from "@/server/http";
import { applyPreview } from "@/server/plan-store";
import { clientIdentifier, guardRequest, readJSONBody } from "@/server/request-guard";

export async function POST(request: Request, context: { params: Promise<{ planId: string; mealId: string }> }) {
  try {
    guardRequest(request, 20, 60_000);
    const { planId, mealId } = await context.params;
    const { previewId } = z.object({ previewId: z.string().uuid() }).strict().parse(await readJSONBody(request));
    const plan = await applyPreview(planId, mealId, previewId, clientIdentifier(request));
    return plan ? Response.json({ plan: apiPlan(plan) }) : notFound("That swap preview is no longer available.");
  } catch (error) { return problemResponse(error); }
}
