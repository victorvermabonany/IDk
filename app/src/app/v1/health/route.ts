import { databaseReady } from "@/server/plan-store";
import { isProductionRuntime, productionConfig } from "@/server/runtime-config";

export async function GET() {
  try {
    if (isProductionRuntime()) productionConfig();
    await databaseReady();
    return Response.json({ status: "ok", service: "weektable-api", livePlanning: process.env.OPENAI_LIVE_PLANNING_ENABLED === "true" });
  } catch {
    return Response.json({ status: "unavailable", service: "weektable-api" }, { status: 503 });
  }
}
