import { PlannerFlow } from "@/components/planner-flow";
import { SiteHeader } from "@/components/site-header";

export default function PlannerPage() {
  return (
    <>
      <SiteHeader backHref="/" />
      <PlannerFlow />
    </>
  );
}
