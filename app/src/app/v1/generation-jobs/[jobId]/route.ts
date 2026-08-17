import { notFound } from "@/server/http";
import { readJob } from "@/server/plan-store";

export async function GET(_request: Request, context: { params: Promise<{ jobId: string }> }) {
  const { jobId } = await context.params; const job = await readJob(jobId);
  return job ? Response.json({ updates: job.updates }) : notFound("That generation job was not found.");
}
