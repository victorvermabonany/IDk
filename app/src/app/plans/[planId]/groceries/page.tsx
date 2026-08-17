import { notFound } from "next/navigation";

import { GroceryList } from "@/components/grocery-list";
import { SiteHeader } from "@/components/site-header";
import { readPlan } from "@/server/plan-store";

export default async function GroceryPage({ params }: { params: Promise<{ planId: string }> }) {
  const { planId } = await params;
  const plan = await readPlan(planId);
  if (!plan) notFound();
  return (
    <>
      <SiteHeader backHref={`/plans/${plan.id}`} />
      <GroceryList initialPlan={plan} />
    </>
  );
}
