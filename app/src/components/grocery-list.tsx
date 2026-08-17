"use client";

import { useEffect, useMemo, useState } from "react";

import type { BasketItem, Department, MealPlan } from "@/domain/types";
import { hydratePlan, type APIPlan } from "@/lib/api-plan";
import { formatMoney, formatQuantity } from "@/lib/format";

const departmentOrder: Department[] = ["Produce", "Meat", "Dairy & eggs", "Bakery", "Pantry", "Canned goods", "Seasonings", "Other"];

function packagePrice(item: BasketItem) {
  if (!item.product) return null;
  return item.packageCount * (item.product.salePriceCents ?? item.product.regularPriceCents);
}

export function GroceryList({ initialPlan }: { initialPlan: MealPlan }) {
  const [plan, setPlan] = useState(initialPlan);
  const [checked, setChecked] = useState<string[]>([]);
  const [owned, setOwned] = useState<string[]>(initialPlan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.id));
  const [shareStatus, setShareStatus] = useState("");
  const [syncError, setSyncError] = useState("");
  const [syncingItemID, setSyncingItemID] = useState<string | null>(null);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const storedPlan = sessionStorage.getItem("cove:plan") ?? sessionStorage.getItem("weektable:plan");
      if (storedPlan) {
        try {
          const nextPlan = hydratePlan(JSON.parse(storedPlan) as APIPlan);
          setPlan(nextPlan);
          setOwned(nextPlan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.id));
        } catch { sessionStorage.removeItem("cove:plan"); sessionStorage.removeItem("weektable:plan"); }
      }
      const storedChecked = localStorage.getItem("weektable:grocery-checked");
      if (storedChecked) {
        try { setChecked(JSON.parse(storedChecked) as string[]); } catch { localStorage.removeItem("weektable:grocery-checked"); }
      }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  const total = plan.estimatedTotalCents;
  const neededItems = plan.basket.filter((item) => !owned.includes(item.id));
  const uncheckedCount = neededItems.filter((item) => !checked.includes(item.id)).length;
  const mealById = useMemo(() => new Map(plan.meals.map((meal) => [meal.id, meal.title])), [plan.meals]);
  const groups = departmentOrder.map((department) => ({
    department,
    items: plan.basket.filter((item) => (item.product?.department ?? "Other") === department),
  })).filter((group) => group.items.length > 0);
  const pricing = plan.pricingProvenance;
  const livePricing = pricing?.pricingMode === "live";

  async function synchronizeGroceryState(nextChecked: string[], nextOwned: string[]) {
    const response = await fetch(`/v1/plans/${plan.id}/grocery-state`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ checkedItemIds: nextChecked, ownedItemIds: nextOwned }),
    });
    if (!response.ok) throw new Error("Grocery state could not be synchronized");
    const payload = await response.json() as { plan: APIPlan };
    const nextPlan = hydratePlan(payload.plan);
    setPlan(nextPlan);
    setOwned(nextPlan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.id));
    sessionStorage.setItem("cove:plan", JSON.stringify(nextPlan));
  }

  async function toggleChecked(id: string) {
    const next = checked.includes(id) ? checked.filter((item) => item !== id) : [...checked, id];
    setChecked(next);
    localStorage.setItem("weektable:grocery-checked", JSON.stringify(next));
    setSyncError("");
    try { await synchronizeGroceryState(next, owned); }
    catch { setSyncError("The checkoff is saved on this device, but could not be synchronized with your plan."); }
  }

  async function toggleOwned(id: string) {
    if (syncingItemID) return;
    const previous = owned;
    const next = previous.includes(id) ? previous.filter((item) => item !== id) : [...previous, id];
    setOwned(next);
    setSyncingItemID(id);
    setSyncError("");
    try { await synchronizeGroceryState(checked, next); }
    catch {
      setOwned(previous);
      setSyncError("Your basket could not be repriced. Nothing changed; try again.");
    } finally { setSyncingItemID(null); }
  }

  async function shareList() {
    const text = [
      "Cove grocery list",
      ...groups.flatMap((group) => [group.department.toUpperCase(), ...group.items.filter((item) => !owned.includes(item.id)).map((item) => `- ${item.product?.name ?? item.displayName} · ${item.product?.displayPackage ?? "price unavailable"}`)]),
      `Estimated total: ${formatMoney(total)}`,
      "Estimated complete-package prices for planning; verify current shelf prices and allergen labels.",
    ].join("\n");
    try {
      const canShare = "share" in navigator;
      if (canShare) await navigator.share({ title: "Cove grocery list", text });
      else await navigator.clipboard.writeText(text);
      setShareStatus(canShare ? "Shared" : "Copied to clipboard");
    } catch { setShareStatus("Sharing was canceled"); }
  }

  return (
    <main className="grocery-page">
      <header className="grocery-summary">
        <div className="page-shell grocery-summary__inner">
          <div><p className="eyebrow">At the store</p><h1>Grocery list</h1><p>{uncheckedCount} items left · {plan.meals.length} dinners</p></div>
          <div className="grocery-total"><span>RUNNING BASKET</span><strong>{formatMoney(total)}</strong><small>of {formatMoney(plan.budgetCents)}</small></div>
        </div>
      </header>

      <div className="catalog-disclosure">
        <div className="page-shell"><strong>{livePricing ? `${pricing?.providerName ?? "Provider"} pricing` : pricing?.pricingMode === "fixture" ? "Development fixture" : "Estimated basket"}</strong><span>{livePricing ? `Provider-listed prices for ${pricing?.storeName ?? plan.store.name}; verify current shelf prices and all labels.` : "Cove complete-package estimates for planning. Prices may differ at your store."}</span></div>
      </div>

      <div className="grocery-layout page-shell">
        <div className="grocery-list">
          {groups.map((group) => (
            <section key={group.department} className="grocery-department" aria-labelledby={`department-${group.department.replaceAll(" ", "-")}`}>
              <div className="department-heading"><h2 id={`department-${group.department.replaceAll(" ", "-")}`}>{group.department}</h2><span>{group.items.length}</span></div>
              <div>
                {group.items.map((item) => {
                  const isOwned = owned.includes(item.id);
                  const isChecked = checked.includes(item.id);
                  const price = packagePrice(item);
                  return (
                    <article className={`grocery-row ${isChecked ? "is-checked" : ""}`} key={item.id}>
                      <button className="grocery-check" type="button" aria-pressed={isChecked} aria-label={`${isChecked ? "Uncheck" : "Check"} ${item.displayName}`} onClick={() => toggleChecked(item.id)}><span aria-hidden="true">{isChecked ? "✓" : ""}</span></button>
                      <div className="grocery-row__main">
                        <h3>{item.product?.name ?? item.displayName}</h3>
                        <p>{item.packageCount || 1} × {item.product?.displayPackage ?? formatQuantity(item.requiredQuantity, item.requiredUnit)} <span>· need {formatQuantity(item.requiredQuantity, item.requiredUnit)}</span></p>
                        <details><summary>Used in {item.mealIds.length} {item.mealIds.length === 1 ? "dinner" : "dinners"}</summary><ul>{item.mealIds.map((id) => <li key={id}>{mealById.get(id) ?? "Dinner"}</li>)}</ul></details>
                      </div>
                      <div className="grocery-row__price">
                        <strong>{isOwned ? "Already have" : price === null ? "Unpriced" : formatMoney(price)}</strong>
                        <button type="button" disabled={syncingItemID !== null} onClick={() => toggleOwned(item.id)}>{syncingItemID === item.id ? "Updating…" : isOwned ? "Add to basket" : "I have this"}</button>
                      </div>
                    </article>
                  );
                })}
              </div>
            </section>
          ))}

          <section className="shopping-complete" aria-live="polite">
            <span>{uncheckedCount === 0 ? "✓" : uncheckedCount}</span>
            <div><h2>{uncheckedCount === 0 ? "List complete." : `${uncheckedCount} items to go.`}</h2><p>Checked items stay visible, so the list never changes shape while you shop.</p></div>
          </section>
          {syncError ? <p role="alert" className="share-status">{syncError}</p> : null}
        </div>

        <aside className="grocery-aside">
          <div className="grocery-aside__summary"><span>Estimated total</span><strong>{formatMoney(total)}</strong><p>{formatMoney(plan.budgetCents - total)} below budget</p><div className="budget-rule"><span style={{ width: `${Math.min(100, (total / plan.budgetCents) * 100)}%` }} /></div></div>
          <button className="button-secondary button-block" type="button" onClick={shareList}>Copy or share list</button>
          {shareStatus ? <p role="status" className="share-status">{shareStatus}</p> : null}
          <p className="grocery-aside__note">Variable-weight items and in-store prices may differ. Cove keeps a budget buffer for that reason.</p>
        </aside>
      </div>
    </main>
  );
}
