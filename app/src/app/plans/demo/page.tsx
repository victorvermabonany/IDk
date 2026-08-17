import { SiteHeader } from "@/components/site-header";
import { WeeklyPlan } from "@/components/weekly-plan";
import { DEFAULT_PLANNER_REQUEST, generatePlan } from "@/domain/planner-service";

export default async function DemoPlanPage() {
  const plan = await generatePlan(DEFAULT_PLANNER_REQUEST);
  return (
    <>
      <SiteHeader backHref="/plan" />
      <WeeklyPlan initialPlan={plan} />
    </>
  );
}
