import { notFound } from "next/navigation";

import { RecipeView } from "@/components/recipe-view";
import { SiteHeader } from "@/components/site-header";
import { readPlan } from "@/server/plan-store";

export default async function RecipePage({ params }: { params: Promise<{ planId: string; mealId: string }> }) {
  const { planId, mealId } = await params;
  const plan = await readPlan(planId);
  if (!plan || !plan.meals.some((meal) => meal.id === mealId)) notFound();
  return (
    <>
      <SiteHeader backHref={`/plans/${plan.id}`} />
      <RecipeView initialPlan={plan} mealId={mealId} />
    </>
  );
}
