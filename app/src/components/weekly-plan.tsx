"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { FoodImage } from "@/components/food-image";
import type { Meal, MealPlan, SwapPreview as ServerSwapPreview } from "@/domain/types";
import { hydratePlan, type APIPlan } from "@/lib/api-plan";
import { formatDelta, formatMoney } from "@/lib/format";

interface SwapPreview {
  id: string;
  meal: Meal;
  deltaCents: number;
  reusedIngredientCount: number;
  resultingTotalCents: number;
}

export function WeeklyPlan({ initialPlan }: { initialPlan: MealPlan }) {
  const [plan, setPlan] = useState(initialPlan);
  const [swapMealId, setSwapMealId] = useState<string | null>(null);
  const [previews, setPreviews] = useState<SwapPreview[]>([]);
  const [loadingSwaps, setLoadingSwaps] = useState(false);
  const [saveMessage, setSaveMessage] = useState("");

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const stored = sessionStorage.getItem("weektable:plan");
      if (!stored) return;
      try { setPlan(JSON.parse(stored) as MealPlan); } catch { sessionStorage.removeItem("weektable:plan"); }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  const remaining = plan.budgetCents - plan.estimatedTotalCents;
  const percent = Math.min(100, Math.round((plan.estimatedTotalCents / plan.budgetCents) * 100));
  const mealTitleById = useMemo(() => new Map(plan.meals.map((meal) => [meal.id, meal.title])), [plan.meals]);

  async function openSwap(mealId: string) {
    setSwapMealId(mealId);
    setLoadingSwaps(true);
    setPreviews([]);
    try {
      const response = await fetch(`/v1/plans/${plan.id}/meals/${mealId}/swap-previews`, { cache: "no-store" });
      if (!response.ok) throw new Error("Swap previews failed");
      const payload = await response.json() as { previews: ServerSwapPreview[] };
      setPreviews(payload.previews);
    } catch { setPreviews([]); }
    setLoadingSwaps(false);
  }

  async function applySwap(preview: SwapPreview) {
    if (preview.resultingTotalCents > plan.budgetCents || !swapMealId) return;
    const response = await fetch(`/v1/plans/${plan.id}/meals/${swapMealId}/swap`, {
      method: "POST", headers: { "Content-Type": "application/json", "Idempotency-Key": crypto.randomUUID() },
      body: JSON.stringify({ previewId: preview.id }),
    });
    if (!response.ok) return;
    const payload = await response.json() as { plan: APIPlan };
    const nextPlan = hydratePlan(payload.plan);
    setPlan(nextPlan);
    sessionStorage.setItem("weektable:plan", JSON.stringify(nextPlan));
    setSwapMealId(null);
  }

  return (
    <main className="weekly-page">
      <section className="week-intro page-shell">
        <div>
          <p className="eyebrow">Your week</p>
          <h1>{plan.meals.length} dinners.<br /><em>One smart basket.</em></h1>
          <p className="week-intro__deck">Built for {plan.meals[0]?.servings ?? 2} people at {plan.store.retailer}.</p>
        </div>
        <aside className="week-budget" aria-label="Budget summary">
          <p><strong>{formatMoney(plan.estimatedTotalCents)}</strong> of {formatMoney(plan.budgetCents)}</p>
          <div className="budget-rule"><span style={{ width: `${percent}%` }} /></div>
          <p className="week-budget__remaining">{formatMoney(remaining)} remaining</p>
          <small>Complete packages · {Math.round(plan.priceCoverage * 100)}% priced</small>
          <Link className="button-primary button-block" href="/plans/demo/groceries">Open grocery list <span aria-hidden="true">→</span></Link>
        </aside>
      </section>

      <div className="catalog-disclosure">
        <div className="page-shell"><strong>Estimated catalog</strong><span>Estimated complete-package prices for planning. Check current shelf prices and labels.</span></div>
      </div>

      <section className="week-meals page-shell" aria-labelledby="meals-heading">
        <div className="week-meals__header"><h2 id="meals-heading">On the table</h2><span>{plan.meals.length} dinners · {plan.meals.reduce((minutes, meal) => minutes + meal.prepMinutes + meal.cookMinutes, 0)} total minutes</span></div>
        <ol>
          {plan.meals.map((meal, index) => (
            <li className="week-meal" key={meal.id}>
              <div className="week-meal__day"><span>{String(index + 1).padStart(2, "0")}</span><strong>{meal.day}</strong></div>
              <Link className="week-meal__image-link" href={`/plans/demo/meals/${meal.id}`}>
                <FoodImage mealId={meal.id} mealTitle={meal.title} alt={meal.title} position={meal.imagePosition} className="week-meal__image" />
              </Link>
              <div className="week-meal__content">
                <Link href={`/plans/demo/meals/${meal.id}`}><h3>{meal.title}</h3></Link>
                <p>{meal.description}</p>
                <div className="meal-meta"><span>{meal.prepMinutes + meal.cookMinutes} min</span><span>{meal.servings} servings</span><span>~{meal.proteinGrams}g protein</span></div>
                <button className="text-action" type="button" onClick={() => openSwap(meal.id)}>Swap this dinner</button>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section className="week-actions page-shell">
        <div><p className="eyebrow">Keep the week</p><h2>Come back to it<br />at the store.</h2></div>
        <div>
          <button className="button-secondary" type="button" onClick={() => setSaveMessage("Account-on-save is ready for the persistence phase; this browser already keeps the demo plan for this session.")}>Save this plan</button>
          {saveMessage ? <p role="status">{saveMessage}</p> : null}
        </div>
      </section>

      {swapMealId ? (
        <div className="swap-scrim" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setSwapMealId(null); }}>
          <section className="swap-sheet" role="dialog" aria-modal="true" aria-labelledby="swap-heading">
            <div className="swap-sheet__header"><div><p className="eyebrow">Keep the basket steady</p><h2 id="swap-heading">Swap {mealTitleById.get(swapMealId)}</h2></div><button type="button" aria-label="Close meal swap" onClick={() => setSwapMealId(null)}>×</button></div>
            {loadingSwaps ? <p className="swap-loading">Repricing complete packages…</p> : null}
            {!loadingSwaps && previews.length === 0 ? <p className="swap-empty">No distinct fixture alternatives remain for this seven-dinner week. The original meal is unchanged.</p> : null}
            <div className="swap-options">
              {previews.map((preview) => {
                const overBudget = preview.resultingTotalCents > plan.budgetCents;
                return (
                  <article key={preview.meal.title}>
                    <div><h3>{preview.meal.title}</h3><p>{preview.meal.prepMinutes + preview.meal.cookMinutes} min · reuses {preview.reusedIngredientCount} basket ingredients</p></div>
                    <div className="swap-option__action"><strong className={preview.deltaCents <= 0 ? "is-saving" : ""}>{formatDelta(preview.deltaCents)}</strong><button className="button-secondary" type="button" disabled={overBudget} onClick={() => applySwap(preview)}>{overBudget ? "Over budget" : "Choose"}</button></div>
                  </article>
                );
              })}
            </div>
          </section>
        </div>
      ) : null}
    </main>
  );
}
