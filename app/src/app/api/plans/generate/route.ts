import { PlanGenerationError, plannerRequestSchema } from "@/domain/types";
import { readJob, readPlan, runGeneration, startGeneration } from "@/server/plan-store";
import { ZodError } from "zod";

export async function POST(request: Request) {
  try {
    const body: unknown = await request.json();
    const input = plannerRequestSchema.parse(body);
    const job = await startGeneration(input, request.headers.get("Idempotency-Key") ?? crypto.randomUUID());
    await runGeneration(job.id);
    const completedJob = await readJob(job.id);
    if (completedJob?.status === "failed") {
      throw new PlanGenerationError(
        completedJob.errorCode === "MODEL_FAILURE" ? "MODEL_FAILURE" : completedJob.errorCode === "PROVIDER_UNAVAILABLE" ? "PROVIDER_UNAVAILABLE" : "CONSTRAINT_CONFLICT",
        completedJob.errorMessage ?? "Cove could not finish this plan.",
      );
    }
    const plan = await readPlan(job.planId);
    if (!plan) throw new Error("Generated plan was not persisted.");
    return Response.json({ plan }, { status: 201 });
  } catch (error) {
    if (error instanceof PlanGenerationError) {
      const status = error.code === "PROVIDER_UNAVAILABLE" ? 503 : error.code === "MODEL_FAILURE" ? 502 : 422;
      return Response.json(
        { error: { code: error.code, message: error.message } },
        { status },
      );
    }

    if (error instanceof ZodError) {
      return Response.json(
        {
          error: {
            code: "INVALID_REQUEST",
            message: "Some planner answers are incomplete or invalid.",
          },
        },
        { status: 400 },
      );
    }

    return Response.json(
      {
        error: {
          code: "GENERATION_FAILED",
          message: "We could not finish this plan. Your planner answers are still saved.",
        },
      },
      { status: 500 },
    );
  }
}
