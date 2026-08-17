import { databaseReady } from "@/server/plan-store";
import { groceryProviderStatus } from "@/domain/grocery-providers";
import { productionConfig, runtimeMode } from "@/server/runtime-config";

export async function GET() {
  const mode = runtimeMode();
  try {
    if (mode !== "development_fixture") productionConfig();
    await databaseReady();
    return Response.json({
      status: "ok",
      service: "cove-api",
      mode,
      dependencies: {
        database: mode === "development_fixture" ? "development_memory" : "ready",
        model: process.env.OPENAI_LIVE_PLANNING_ENABLED === "true" ? "configured" : "fixture_only",
        grocery: groceryProviderStatus(),
      },
    });
  } catch {
    return Response.json({ status: "unavailable", service: "cove-api", mode }, { status: 503 });
  }
}
