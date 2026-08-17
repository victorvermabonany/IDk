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
      const stored = sessionStorage.getItem("weektable:request");
      if (stored) {
        try { plannerRequest = JSON.parse(stored) as PlannerRequest; } catch { /* use safe defaults */ }
      }

      try {
        const response = await fetch("/api/plans/generate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(plannerRequest),
          signal: controller.signal,
        });
        const payload = await response.json() as { plan?: MealPlan; error?: { message: string } };
        if (!response.ok || !payload.plan) throw new Error(payload.error?.message ?? "The plan could not be completed.");

        const wait = Math.max(0, 3100 - (Date.now() - startedAt));
        await new Promise((resolve) => window.setTimeout(resolve, wait));
        sessionStorage.setItem("weektable:plan", JSON.stringify(payload.plan));
        setStage(stages.length - 1);
        router.replace("/plans/demo");
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
