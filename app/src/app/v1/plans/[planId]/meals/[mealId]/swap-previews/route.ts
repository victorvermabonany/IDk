import { apiSwapPreview } from "@/server/api-dto";
import { notFound, problemResponse } from "@/server/http";
import { previewsFor, readPlan } from "@/server/plan-store";
import { guardRequest } from "@/server/request-guard";

export async function GET(request: Request, context: { params: Promise<{ planId: string; mealId: string }> }) {
  try {
    guardRequest(request, 20, 60_000);
    const { planId, mealId } = await context.params;
    if (!await readPlan(planId)) return notFound("That plan was not found.");
    const previews = await previewsFor(planId, mealId);
    return Response.json({ previews: previews.map(apiSwapPreview) });
  } catch (error) { return problemResponse(error); }
}
