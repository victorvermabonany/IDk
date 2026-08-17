import { notFound } from "next/navigation";

import { SiteHeader } from "@/components/site-header";
import { WeeklyPlan } from "@/components/weekly-plan";
import { readPlan } from "@/server/plan-store";

export default async function PlanPage({ params }: { params: Promise<{ planId: string }> }) {
  const { planId } = await params;
  const plan = await readPlan(planId);
  if (!plan) notFound();
  return (
    <>
      <SiteHeader backHref="/plan" />
      <WeeklyPlan initialPlan={plan} />
    </>
  );
}
