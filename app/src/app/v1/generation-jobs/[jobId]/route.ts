import { notFound } from "@/server/http";
import { readJob, runGeneration } from "@/server/plan-store";
import { after } from "next/server";

export const maxDuration = 120;

export async function GET(_request: Request, context: { params: Promise<{ jobId: string }> }) {
  const { jobId } = await context.params; const job = await readJob(jobId);
  if (!job) return notFound("That generation job was not found.");
  if (job.status === "failed") {
    const status = job.errorCode === "MODEL_FAILURE" ? 502 : job.errorCode === "PROVIDER_UNAVAILABLE" ? 503 : 422;
    return Response.json({ error: { code: job.errorCode ?? "GENERATION_FAILED", message: job.errorMessage ?? "Cove could not finish this plan." } }, { status });
  }
  if (job.status !== "completed") after(() => runGeneration(job.id));
  return Response.json({ updates: job.updates });
}
