"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import type { PlannerRequest } from "@/domain/types";
import { CLIENT_DEFAULT_REQUEST } from "@/lib/planner-defaults";

const steps = ["Store & budget", "Household", "Food", "Pantry"];
const nutritionOptions: Array<{ value: PlannerRequest["nutritionStyle"]; label: string; note: string }> = [
  { value: "balanced", label: "Balanced", note: "A little of everything" },
  { value: "high-protein", label: "High protein", note: "Protein-forward dinners" },
  { value: "vegetarian", label: "Vegetarian", note: "No meat or seafood" },
  { value: "quick", label: "Quick & easy", note: "Fewer steps, less cleanup" },
  { value: "budget-first", label: "Budget first", note: "Stretch every package" },
  { value: "lighter", label: "Generally lighter", note: "Fresh, unfussy meals" },
];
const pantrySuggestions = ["olive oil", "salt", "black pepper", "rice", "eggs", "soy sauce"];
const allergyOptions = ["milk", "eggs", "peanuts", "tree nuts", "soy", "wheat", "fish", "shellfish"];
const dietaryOptions = ["gluten-free", "dairy-free", "vegan"];
const cuisineOptions = ["Mexican", "Italian", "Mediterranean", "Asian-inspired"];

export function PlannerFlow() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [form, setForm] = useState<PlannerRequest>(CLIENT_DEFAULT_REQUEST);
  const [dislikesText, setDislikesText] = useState(CLIENT_DEFAULT_REQUEST.dislikedFoods.join(", "));
  const [pantryText, setPantryText] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const saved = sessionStorage.getItem("weektable:planner-draft");
      if (!saved) return;
      try {
        const draft = JSON.parse(saved) as { form: PlannerRequest; dislikesText: string; pantryText: string; step: number };
        setForm(draft.form);
        setDislikesText(draft.dislikesText);
        setPantryText(draft.pantryText);
        setStep(Math.min(draft.step, 3));
      } catch {
        sessionStorage.removeItem("weektable:planner-draft");
      }
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    sessionStorage.setItem(
      "weektable:planner-draft",
      JSON.stringify({ form, dislikesText, pantryText, step }),
    );
  }, [form, dislikesText, pantryText, step]);

  function setField<K extends keyof PlannerRequest>(key: K, value: PlannerRequest[K]) {
    setForm((current) => ({ ...current, [key]: value }));
    setError("");
  }

  function setPostalCode(postalCode: string) {
    setField("store", { ...form.store, postalCode });
  }

  function setStore(id: string) {
    setField("store", {
      ...form.store,
      id,
      locationId: id === "demo-value-45202" ? "fixture-value-45202" : "fixture-45202",
    });
  }

  function toggleAllergy(value: string) {
    setField(
      "allergies",
      form.allergies.includes(value)
        ? form.allergies.filter((item) => item !== value)
        : [...form.allergies, value],
    );
  }

  function toggleArrayField(key: "dietaryRestrictions" | "preferredCuisines", value: string) {
    const values = form[key];
    setField(key, values.includes(value) ? values.filter((item) => item !== value) : [...values, value]);
  }

  function togglePantry(value: string) {
    setField(
      "pantryItems",
      form.pantryItems.includes(value)
        ? form.pantryItems.filter((item) => item !== value)
        : [...form.pantryItems, value],
    );
  }

  function next() {
    if (step === 0 && !/^\d{5}$/.test(form.store.postalCode)) {
      setError("Enter a five-digit ZIP code.");
      return;
    }
    if (step === 0 && form.budgetCents < 2_000) {
      setError("The minimum planning budget is $20.");
      return;
    }
    setStep((current) => Math.min(current + 1, 3));
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function submit() {
    const customPantry = pantryText.split(",").map((item) => item.trim()).filter(Boolean);
    const request: PlannerRequest = {
      ...form,
      dislikedFoods: dislikesText.split(",").map((item) => item.trim()).filter(Boolean),
      pantryItems: [...new Set([...form.pantryItems, ...customPantry])],
    };
    sessionStorage.setItem("weektable:request", JSON.stringify(request));
    sessionStorage.removeItem("weektable:plan");
    router.push("/plan/generating");
  }

  return (
    <main className="planner-page page-shell">
      <div className="planner-progress" aria-label={`Step ${step + 1} of ${steps.length}`}>
        <div className="planner-progress__meta">
          <span>Step {step + 1} of {steps.length}</span>
          <span>{steps[step]}</span>
        </div>
        <div className="planner-progress__track"><span style={{ width: `${((step + 1) / steps.length) * 100}%` }} /></div>
      </div>

      <form className="planner-form" onSubmit={(event) => event.preventDefault()}>
        {step === 0 ? (
          <section className="planner-step" aria-labelledby="store-heading">
            <p className="eyebrow">Start with the real-world part</p>
            <h1 id="store-heading">Where do you shop,<br />and what should we spend?</h1>
            <p className="step-deck">We use the store location to match complete packages—not fractional ingredient costs.</p>
            <div className="field-grid field-grid--two">
              <label className="field">
                <span>ZIP code</span>
                <input inputMode="numeric" autoComplete="postal-code" maxLength={5} value={form.store.postalCode} onChange={(event) => setPostalCode(event.target.value.replace(/\D/g, ""))} />
              </label>
              <label className="field budget-field">
                <span>Weekly dinner budget</span>
                <div className="money-input"><span>$</span><input inputMode="decimal" type="number" min={20} max={500} value={form.budgetCents / 100} onChange={(event) => setField("budgetCents", Math.round(Number(event.target.value) * 100))} /></div>
              </label>
            </div>
            <label className="field">
              <span>Store location</span>
              <select value={form.store.id} onChange={(event) => setStore(event.target.value)}>
                <option value="demo-kroger-45202">Central Market · Estimated catalog</option>
                <option value="demo-value-45202">Value Market · Central demo — Cincinnati, OH</option>
              </select>
              <small>This beta uses estimated complete-package catalog prices for planning. Check current shelf prices and labels.</small>
            </label>
          </section>
        ) : null}

        {step === 1 ? (
          <section className="planner-step" aria-labelledby="household-heading">
            <p className="eyebrow">Set the table</p>
            <h1 id="household-heading">How much dinner<br />does the week need?</h1>
            <div className="counter-row">
              <div><strong>People eating</strong><span>1 to 8 people</span></div>
              <div className="counter-control">
                <button type="button" aria-label="Remove one person" onClick={() => setField("householdSize", Math.max(1, form.householdSize - 1))}>−</button>
                <output aria-live="polite">{form.householdSize}</output>
                <button type="button" aria-label="Add one person" onClick={() => setField("householdSize", Math.min(8, form.householdSize + 1))}>+</button>
              </div>
            </div>
            <fieldset className="choice-fieldset">
              <legend>How many dinners?</legend>
              <div className="segmented-control segmented-control--meals">
                {[3, 4, 5, 6, 7].map((count) => (
                  <button type="button" key={count} aria-pressed={form.dinnerCount === count} onClick={() => setField("dinnerCount", count)}>{count}</button>
                ))}
              </div>
            </fieldset>
            <label className="check-line">
              <input type="checkbox" checked={form.leftovers.enabled} onChange={(event) => setField("leftovers", { enabled: event.target.checked, extraServings: event.target.checked ? 1 : 0 })} />
              <span><strong>Plan for leftovers</strong><small>Useful for next-day lunches; never reduces dinner servings.</small></span>
            </label>
          </section>
        ) : null}

        {step === 2 ? (
          <section className="planner-step" aria-labelledby="food-heading">
            <p className="eyebrow">Make the week yours</p>
            <h1 id="food-heading">How do you want<br />dinner to feel?</h1>
            <fieldset className="choice-fieldset">
              <legend>General direction</legend>
              <div className="preference-grid">
                {nutritionOptions.map((option) => (
                  <button type="button" key={option.value} aria-pressed={form.nutritionStyle === option.value} onClick={() => setField("nutritionStyle", option.value)}>
                    <strong>{option.label}</strong><span>{option.note}</span>
                  </button>
                ))}
              </div>
            </fieldset>
            <fieldset className="choice-fieldset">
              <legend>Maximum total cooking time</legend>
              <div className="segmented-control">
                {[20, 30, 40, 60].map((minutes) => (
                  <button type="button" key={minutes} aria-pressed={form.maxCookingMinutes === minutes} onClick={() => setField("maxCookingMinutes", minutes)}>{minutes} min</button>
                ))}
              </div>
            </fieldset>
            <fieldset className="choice-fieldset">
              <legend>Allergies <small>Hard constraints</small></legend>
              <div className="check-grid">
                {allergyOptions.map((allergy) => (
                  <label key={allergy}><input type="checkbox" checked={form.allergies.includes(allergy)} onChange={() => toggleAllergy(allergy)} /><span>{allergy}</span></label>
                ))}
              </div>
              <p className="safety-note">Always verify packaged-food labels. Product data cannot guarantee cross-contact safety.</p>
            </fieldset>
            <fieldset className="choice-fieldset">
              <legend>Dietary restrictions <small>Hard constraints</small></legend>
              <div className="check-grid">
                {dietaryOptions.map((restriction) => (
                  <label key={restriction}><input type="checkbox" checked={form.dietaryRestrictions.includes(restriction)} onChange={() => toggleArrayField("dietaryRestrictions", restriction)} /><span>{restriction}</span></label>
                ))}
              </div>
            </fieldset>
            <label className="field">
              <span>Foods to avoid</span>
              <input value={dislikesText} onChange={(event) => setDislikesText(event.target.value)} placeholder="mushrooms, seafood" />
              <small>Separate foods with commas.</small>
            </label>
            <fieldset className="choice-fieldset">
              <legend>Cuisines you enjoy <small>Preference</small></legend>
              <div className="check-grid">
                {cuisineOptions.map((cuisine) => (
                  <label key={cuisine}><input type="checkbox" checked={form.preferredCuisines.includes(cuisine)} onChange={() => toggleArrayField("preferredCuisines", cuisine)} /><span>{cuisine}</span></label>
                ))}
              </div>
            </fieldset>
            <label className="field">
              <span>Instructions for this week <small>Optional</small></span>
              <textarea rows={3} maxLength={400} value={form.customInstructions} onChange={(event) => setField("customInstructions", event.target.value)} placeholder="Keep it mild, don't use an oven, meals should reheat well…" />
              <small>Safety, dietary, time, serving, and budget constraints always take priority.</small>
            </label>
          </section>
        ) : null}

        {step === 3 ? (
          <section className="planner-step" aria-labelledby="pantry-heading">
            <p className="eyebrow">Use what is already there</p>
            <h1 id="pantry-heading">What can stay<br />off the grocery bill?</h1>
            <p className="step-deck">These ingredients remain in the recipes, but move to “Already have” and come out of the subtotal.</p>
            <fieldset className="choice-fieldset">
              <legend>Common staples</legend>
              <div className="pantry-options">
                {pantrySuggestions.map((item) => (
                  <button type="button" key={item} aria-pressed={form.pantryItems.includes(item)} onClick={() => togglePantry(item)}>
                    <span aria-hidden="true">{form.pantryItems.includes(item) ? "✓" : "+"}</span>{item}
                  </button>
                ))}
              </div>
            </fieldset>
            <label className="field">
              <span>Anything else?</span>
              <textarea rows={3} value={pantryText} onChange={(event) => setPantryText(event.target.value)} placeholder="pasta, garlic powder, frozen peas" />
              <small>Separate ingredients with commas. This step is optional.</small>
            </label>
          </section>
        ) : null}

        {error ? <p className="form-error" role="alert">{error}</p> : null}
        <div className="planner-actions">
          {step > 0 ? <button className="button-secondary" type="button" onClick={() => setStep((current) => current - 1)}>Back</button> : <span />}
          {step < 3 ? <button className="button-primary" type="button" onClick={next}>Continue <span aria-hidden="true">→</span></button> : <button className="button-primary" type="button" onClick={submit}>Build my week <span aria-hidden="true">→</span></button>}
        </div>
      </form>
    </main>
  );
}
