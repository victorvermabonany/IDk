"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { FoodImage } from "@/components/food-image";
import type { Meal, MealPlan, SwapPreview as ServerSwapPreview } from "@/domain/types";
import { hydratePlan, type APIPlan } from "@/lib/api-plan";
import { formatMoney } from "@/lib/format";

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
  const [applyingPreviewId, setApplyingPreviewId] = useState<string | null>(null);
  const [swapError, setSwapError] = useState("");
  const [saveMessage, setSaveMessage] = useState("");

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const stored = sessionStorage.getItem("cove:plan") ?? sessionStorage.getItem("weektable:plan");
      if (!stored) return;
      try { setPlan(hydratePlan(JSON.parse(stored) as APIPlan)); } catch { sessionStorage.removeItem("cove:plan"); sessionStorage.removeItem("weektable:plan"); }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  const remaining = plan.budgetCents - plan.estimatedTotalCents;
  const percent = Math.min(100, Math.round((plan.estimatedTotalCents / plan.budgetCents) * 100));
  const mealTitleById = useMemo(() => new Map(plan.meals.map((meal) => [meal.id, meal.title])), [plan.meals]);
  const pricing = plan.pricingProvenance;
  const livePricing = pricing?.pricingMode === "live";

  async function openSwap(mealId: string) {
    setSwapMealId(mealId);
    setLoadingSwaps(true);
    setPreviews([]);
    setSwapError("");
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
    setApplyingPreviewId(preview.id);
    setSwapError("");
    try {
      const response = await fetch(`/v1/plans/${plan.id}/meals/${swapMealId}/swap`, {
        method: "POST", headers: { "Content-Type": "application/json", "Idempotency-Key": crypto.randomUUID() },
        body: JSON.stringify({ previewId: preview.id }),
      });
      if (!response.ok) throw new Error("Swap failed");
      const payload = await response.json() as { plan: APIPlan };
      const nextPlan = hydratePlan(payload.plan);
      setPlan(nextPlan);
      sessionStorage.setItem("cove:plan", JSON.stringify(nextPlan));
      setSwapMealId(null);
    } catch {
      setSwapError("Cove couldn’t apply that swap. Your original week is unchanged. Try again.");
    } finally {
      setApplyingPreviewId(null);
    }
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
          <Link className="button-primary button-block" href={`/plans/${plan.id}/groceries`}>Open grocery list <span aria-hidden="true">→</span></Link>
        </aside>
      </section>

      <div className="catalog-disclosure">
        <div className="page-shell"><strong>{livePricing ? `${pricing?.providerName ?? "Provider"} pricing` : pricing?.pricingMode === "fixture" ? "Development fixture" : "Estimated basket"}</strong><span>{livePricing ? `Provider-listed prices for ${pricing?.storeName ?? plan.store.name}, observed ${new Date(pricing?.updatedAt ?? plan.priceObservedAt).toLocaleString()}. Verify current shelf prices and labels.` : "Cove complete-package estimates for planning. Prices may differ at your store."}</span></div>
      </div>

      <section className="week-meals page-shell" aria-labelledby="meals-heading">
        <div className="week-meals__header"><h2 id="meals-heading">On the table</h2><span>{plan.meals.length} dinners · {plan.meals.reduce((minutes, meal) => minutes + meal.prepMinutes + meal.cookMinutes, 0)} total minutes</span></div>
        <ol>
          {plan.meals.map((meal, index) => (
            <li className="week-meal" key={meal.id}>
              <div className="week-meal__day"><span>{String(index + 1).padStart(2, "0")}</span><strong>{meal.day}</strong></div>
              <Link className="week-meal__image-link" href={`/plans/${plan.id}/meals/${meal.id}`}>
                <FoodImage mealId={meal.id} mealTitle={meal.title} alt={meal.title} position={meal.imagePosition} className="week-meal__image" priority={index === 0} />
              </Link>
              <div className="week-meal__content">
                <Link href={`/plans/${plan.id}/meals/${meal.id}`}><h3>{meal.title}</h3></Link>
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
          <button className="button-secondary" type="button" onClick={() => setSaveMessage("This plan is saved for this Cove session.")}>Save this plan</button>
          {saveMessage ? <p role="status">{saveMessage}</p> : null}
        </div>
      </section>

      {swapMealId ? (
        <div className="swap-scrim" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setSwapMealId(null); }}>
          <section className="swap-sheet" role="dialog" aria-modal="true" aria-labelledby="swap-heading">
            <div className="swap-sheet__header"><div><p className="eyebrow">Keep the basket steady</p><h2 id="swap-heading">Swap {mealTitleById.get(swapMealId)}</h2></div><button type="button" aria-label="Close meal swap" onClick={() => setSwapMealId(null)}>×</button></div>
            {loadingSwaps ? <p className="swap-loading">Repricing complete packages…</p> : null}
            {!loadingSwaps && previews.length === 0 ? <p className="swap-empty">No distinct alternatives remain for this week. The original meal is unchanged.</p> : null}
            {swapError ? <p className="swap-error" role="alert">{swapError}</p> : null}
            <div className="swap-options">
              {previews.map((preview) => {
                const overBudget = preview.resultingTotalCents > plan.budgetCents;
                return (
                  <article key={preview.meal.title}>
                    <FoodImage mealId={preview.meal.id} mealTitle={preview.meal.title} alt="" decorative className="swap-option__image" />
                    <div><h3>{preview.meal.title}</h3><p>{preview.meal.prepMinutes + preview.meal.cookMinutes} min · reuses {preview.reusedIngredientCount} basket ingredients</p></div>
                    <div className="swap-option__action"><strong className={preview.deltaCents <= 0 ? "is-saving" : ""}>{preview.deltaCents < 0 ? `Save ${formatMoney(Math.abs(preview.deltaCents))}` : preview.deltaCents > 0 ? `Add ${formatMoney(preview.deltaCents)}` : "No basket change"}</strong><small>Full weekly basket</small><button className="button-secondary" type="button" disabled={overBudget || applyingPreviewId !== null} onClick={() => applySwap(preview)}>{overBudget ? `Over budget · ${formatMoney(preview.resultingTotalCents)}` : applyingPreviewId === preview.id ? "Applying…" : `Choose meal · New basket ${formatMoney(preview.resultingTotalCents)}`}</button></div>
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
