import { apiPlan } from "@/server/api-dto";
import { notFound } from "@/server/http";
import { readPlan } from "@/server/plan-store";

export async function GET(_request: Request, context: { params: Promise<{ planId: string }> }) {
  const { planId } = await context.params; const plan = await readPlan(planId);
  return plan ? Response.json({ plan: apiPlan(plan) }) : notFound("That plan was not found.");
}
