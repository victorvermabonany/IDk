import { RecipeView } from "@/components/recipe-view";
import { SiteHeader } from "@/components/site-header";
import { DEFAULT_PLANNER_REQUEST, generatePlan } from "@/domain/planner-service";

export default async function RecipePage({ params }: { params: Promise<{ mealId: string }> }) {
  const { mealId } = await params;
  const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
  return (
    <>
      <SiteHeader backHref="/plans/demo" />
      <RecipeView initialPlan={plan} mealId={mealId} />
    </>
  );
}
