"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { FoodImage } from "@/components/food-image";
import type { MealPlan } from "@/domain/types";
import { formatMoney, formatQuantity } from "@/lib/format";

export function RecipeView({ initialPlan, mealId }: { initialPlan: MealPlan; mealId: string }) {
  const [plan, setPlan] = useState(initialPlan);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const stored = sessionStorage.getItem("weektable:plan");
      if (!stored) return;
      try { setPlan(JSON.parse(stored) as MealPlan); } catch { sessionStorage.removeItem("weektable:plan"); }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  const meal = plan.meals.find((item) => item.id === mealId) ?? initialPlan.meals.find((item) => item.id === mealId) ?? initialPlan.meals[0];
  const contribution = plan.basket.reduce((sum, item) => item.mealIds.includes(meal.id) && item.totalPriceCents !== null ? sum + item.totalPriceCents / item.mealIds.length : sum, 0);
  const shared = useMemo(() => plan.basket.filter((item) => item.mealIds.includes(meal.id) && item.mealIds.length > 1), [meal.id, plan.basket]);

  return (
    <main className="recipe-page">
      <section className="recipe-hero page-shell">
        <div className="recipe-hero__copy">
          <p className="eyebrow">{meal.day} dinner</p>
          <h1>{meal.title}</h1>
          <p>{meal.description}</p>
          <dl className="recipe-meta">
            <div><dt>Total time</dt><dd>{meal.prepMinutes + meal.cookMinutes} min</dd></div>
            <div><dt>Servings</dt><dd>{meal.servings}</dd></div>
            <div><dt>Basket share</dt><dd>{formatMoney(Math.round(contribution))}</dd></div>
          </dl>
        </div>
        <FoodImage mealId={meal.id} mealTitle={meal.title} className="recipe-photo" alt={meal.title} position={meal.imagePosition} priority />
      </section>

      <div className="recipe-body page-shell">
        <aside className="recipe-ingredients">
          <p className="eyebrow">For the counter</p>
          <h2>Ingredients</h2>
          <ul>{meal.ingredients.map((ingredient) => <li key={`${ingredient.ingredientId}-${ingredient.quantity}`}><span>{ingredient.name}</span><strong>{formatQuantity(ingredient.quantity, ingredient.unit)}</strong></li>)}</ul>
          {shared.length > 0 ? <div className="shared-note"><strong>Working twice this week</strong><p>{shared.slice(0, 4).map((item) => item.displayName).join(", ")} also appear in other dinners.</p></div> : null}
        </aside>

        <section className="recipe-steps">
          <p className="eyebrow">At the stove</p>
          <h2>Make dinner</h2>
          <ol>{meal.instructions.map((instruction, index) => <li key={instruction}><span>{String(index + 1).padStart(2, "0")}</span><p>{instruction}</p></li>)}</ol>
          <div className="nutrition-line"><span>Approximate recipe nutrition</span><strong>~{meal.calories} kcal · ~{meal.proteinGrams}g protein / serving</strong><small>Planning estimate, not medical nutrition guidance.</small></div>
          <div className="recipe-actions"><Link className="button-primary" href="/plans/demo/groceries">Open grocery list</Link><Link className="button-secondary" href="/plans/demo">Back to the week</Link></div>
        </section>
      </div>

      <section className="allergen-reminder"><div className="page-shell"><strong>Cook with care.</strong><p>Weektable treats selected allergies as hard recipe constraints, but packaged-food labels and cross-contact warnings must still be verified.</p></div></section>
    </main>
  );
}
