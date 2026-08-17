import { z } from "zod";
import { apiPlan } from "@/server/api-dto";
import { notFound, problemResponse } from "@/server/http";
import { updateGroceryState } from "@/server/plan-store";
import { guardRequest, readJSONBody } from "@/server/request-guard";

const stateSchema = z.object({ checkedItemIds: z.array(z.string().min(1).max(120)).max(300), ownedItemIds: z.array(z.string().min(1).max(120)).max(300) });
export async function PATCH(request: Request, context: { params: Promise<{ planId: string }> }) {
  try {
    guardRequest(request, 60, 60_000);
    const { planId } = await context.params; const state = stateSchema.parse(await readJSONBody(request));
    const plan = await updateGroceryState(planId, new Set(state.checkedItemIds), new Set(state.ownedItemIds));
    return plan ? Response.json({ plan: apiPlan(plan) }) : notFound("That plan was not found.");
  } catch (error) { return problemResponse(error); }
}
