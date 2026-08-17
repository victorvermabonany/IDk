import { GroceryList } from "@/components/grocery-list";
import { SiteHeader } from "@/components/site-header";
import { DEFAULT_PLANNER_REQUEST, generatePlan } from "@/domain/planner-service";

export default async function GroceryPage() {
  const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
  return (
    <>
      <SiteHeader backHref="/plans/demo" />
      <GroceryList initialPlan={plan} />
    </>
  );
}
