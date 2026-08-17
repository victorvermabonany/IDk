"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import type { MealPlan, PlannerRequest } from "@/domain/types";
import { CLIENT_DEFAULT_REQUEST } from "@/lib/planner-defaults";

const stages = [
  "Planning your meals",
  "Combining ingredients",
  "Checking complete packages",
  "Balancing your budget",
  "Finalizing your week",
];

export function GenerationState() {
  const router = useRouter();
  const [stage, setStage] = useState(0);
  const [error, setError] = useState("");

  useEffect(() => {
    const controller = new AbortController();
    const startedAt = Date.now();
    const interval = window.setInterval(() => {
      setStage((current) => Math.min(current + 1, stages.length - 1));
    }, 620);

    async function run() {
      let plannerRequest: PlannerRequest = CLIENT_DEFAULT_REQUEST;
      const stored = sessionStorage.getItem("cove:request") ?? sessionStorage.getItem("weektable:request");
      if (stored) {
        try { plannerRequest = JSON.parse(stored) as PlannerRequest; } catch { /* use safe defaults */ }
      }

      try {
        let job = (() => {
          const storedJob = sessionStorage.getItem("cove:generation-job");
          if (!storedJob) return null;
          try { return JSON.parse(storedJob) as { id: string; planId: string }; }
          catch { sessionStorage.removeItem("cove:generation-job"); return null; }
        })();
        if (!job) {
          const idempotencyKey = sessionStorage.getItem("cove:generation-key") ?? crypto.randomUUID();
          sessionStorage.setItem("cove:generation-key", idempotencyKey);
          const response = await fetch("/v1/plan-requests", {
            method: "POST",
            headers: { "Content-Type": "application/json", "Idempotency-Key": idempotencyKey },
            body: JSON.stringify(plannerRequest),
            signal: controller.signal,
          });
          const payload = await response.json() as { job?: { id: string; planId: string }; error?: { message: string } };
          if (!response.ok || !payload.job) throw new Error(payload.error?.message ?? "The plan could not be started.");
          job = payload.job;
          sessionStorage.setItem("cove:generation-job", JSON.stringify(job));
        }

        let completedPlanID: string | null = null;
        while (!completedPlanID) {
          const response = await fetch(`/v1/generation-jobs/${encodeURIComponent(job.id)}`, { cache: "no-store", signal: controller.signal });
          const payload = await response.json() as { updates?: Array<{ stage: string; completedPlanId: string | null }>; error?: { message: string } };
          if (!response.ok) throw new Error(payload.error?.message ?? "The plan could not be completed.");
          const latest = payload.updates?.at(-1);
          if (latest) {
            const nextStage = stages.indexOf(latest.stage);
            if (nextStage >= 0) setStage(nextStage);
            completedPlanID = latest.completedPlanId;
          }
          if (!completedPlanID) await new Promise((resolve) => window.setTimeout(resolve, 1_000));
          if (controller.signal.aborted) return;
        }

        const planResponse = await fetch(`/v1/plans/${encodeURIComponent(completedPlanID)}`, { cache: "no-store", signal: controller.signal });
        const planPayload = await planResponse.json() as { plan?: MealPlan; error?: { message: string } };
        if (!planResponse.ok || !planPayload.plan) throw new Error(planPayload.error?.message ?? "The completed plan could not be loaded.");

        const wait = Math.max(0, 3100 - (Date.now() - startedAt));
        await new Promise((resolve) => window.setTimeout(resolve, wait));
        sessionStorage.setItem("cove:plan", JSON.stringify(planPayload.plan));
        sessionStorage.removeItem("cove:generation-job");
        sessionStorage.removeItem("cove:generation-key");
        setStage(stages.length - 1);
        router.replace(`/plans/${encodeURIComponent(planPayload.plan.id)}`);
      } catch (caught) {
        if (controller.signal.aborted) return;
        setError(caught instanceof Error ? caught.message : "The plan could not be completed.");
      } finally {
        window.clearInterval(interval);
      }
    }

    run();
    return () => {
      controller.abort();
      window.clearInterval(interval);
    };
  }, [router]);

  return (
    <main className="generation-page page-shell" aria-live="polite">
      <div className="generation-mark" aria-hidden="true"><span /></div>
      {error ? (
        <section className="generation-error">
          <p className="eyebrow">We kept your answers</p>
          <h1>This week needs<br />one adjustment.</h1>
          <p>{error}</p>
          <Link className="button-primary" href="/plan">Review my planner</Link>
        </section>
      ) : (
        <section>
          <p className="eyebrow">Building a practical week</p>
          <h1>{stages[stage]}<span aria-hidden="true">…</span></h1>
          <div className="generation-track"><span style={{ width: `${((stage + 1) / stages.length) * 100}%` }} /></div>
          <ol className="generation-stages">
            {stages.map((label, index) => <li key={label} className={index <= stage ? "is-active" : ""}>{index < stage ? "Done" : index === stage ? "Now" : "Next"}<span>{label}</span></li>)}
          </ol>
          <p className="generation-note">Estimated prices and package quantities come from the grocery catalog, never from the model. Check current shelf prices and labels.</p>
        </section>
      )}
    </main>
  );
}
