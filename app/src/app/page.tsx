import Image from "next/image";
import Link from "next/link";

import { FoodImage } from "@/components/food-image";

const featuredMeals = [
  { id: "pesto-rigatoni", day: "MON", title: "Chicken pesto rigatoni", time: "30 min" },
  { id: "crispy-chicken-tacos", day: "TUE", title: "Crispy chicken tacos", time: "27 min" },
  { id: "turkey-rice-bowls", day: "WED", title: "Turkey rice bowls", time: "30 min" },
];

function BrandMark() {
  return (
    <Link className="landing-brand" href="/" aria-label="Weektable home">
      <Image src="/weektable-app-icon.png" alt="" width={34} height={34} priority />
      <span>Weektable</span>
    </Link>
  );
}

function PlanLink({ className = "landing-button" }: { className?: string }) {
  return <Link className={className} href="/plan">Plan my week <span aria-hidden="true">→</span></Link>;
}

function WeekProductView() {
  return (
    <div className="product-phone" aria-label="Example Weektable weekly plan">
      <div className="product-phone__bar"><span>9:41</span><strong>This week</strong><span aria-hidden="true">•••</span></div>
      <div className="product-week-card">
        <FoodImage className="product-week-card__photo" alt="" decorative priority />
        <div className="product-week-card__shade" />
        <div className="product-week-card__content">
          <div><span>THIS WEEK</span><strong>5 dinners</strong></div>
          <p><b>$93.42</b><span> / $100</span></p>
          <div><strong>$6.58 left</strong><span className="product-grocery-pill">Grocery list</span></div>
        </div>
      </div>
      <div className="product-phone__heading"><strong>Your meals</strong><span>5 dinners · 157 min</span></div>
      <div className="product-meal-stack">
        {featuredMeals.map((meal) => (
          <article key={meal.id}>
            <FoodImage mealId={meal.id} alt="" decorative className="product-meal-thumb" />
            <div><span>{meal.day}</span><strong>{meal.title}</strong><small>{meal.time}</small></div>
          </article>
        ))}
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <main className="public-landing">
      <header className="landing-nav page-shell">
        <BrandMark />
        <nav aria-label="Primary navigation"><a href="#how-it-works">How it works</a><a href="#product">Product</a></nav>
        <PlanLink className="landing-button landing-button--small" />
      </header>

      <section className="consumer-hero page-shell">
        <div className="consumer-hero__copy">
          <p className="landing-eyebrow">Dinner planning that starts with real life</p>
          <h1>Your week of food, <span>figured out.</span></h1>
          <p className="consumer-hero__deck">Tell us where you shop, what you want to spend, and how you like to eat. We’ll build your meals and one grocery list around it.</p>
          <div className="consumer-hero__actions"><PlanLink /><span>About 3 minutes · no account needed</span></div>
          <dl className="outcome-row" aria-label="Example weekly outcome">
            <div><dt>Dinners</dt><dd>5</dd></div><div><dt>Basket</dt><dd>$93.42 <small>of $100</small></dd></div><div><dt>Left</dt><dd>$6.58</dd></div><div><dt>Lists</dt><dd>One</dd></div>
          </dl>
        </div>
        <div className="consumer-hero__visual"><WeekProductView /></div>
      </section>

      <section className="trust-line" aria-label="Weektable principles"><div className="page-shell"><span>Budget-led planning</span><span>Complete-package math</span><span>Store-aware pricing where supported</span></div></section>

      <section id="how-it-works" className="landing-intro page-shell">
        <p className="landing-eyebrow">One plan, not five disconnected recipes</p>
        <h2>The meals, the basket, and the budget all move together.</h2>
        <p>Weektable works backward from what matters at checkout, then builds a week that shares ingredients without making every dinner taste the same.</p>
      </section>

      <section id="product" className="product-story product-story--budget page-shell">
        <div className="story-copy"><span className="story-number">01</span><p className="landing-eyebrow">Your budget comes first</p><h2>Know the basket before you fall for the recipes.</h2><p>Set the number that works for your household. Weektable prices complete packages, builds a coherent set of dinners, and leaves the breathing room visible.</p></div>
        <div className="budget-proof" aria-label="Example budget result">
          <div className="budget-proof__top"><span>WEEKLY BASKET</span><strong>5 dinners</strong></div><p><b>$93.42</b><span> / $100</span></p><div className="budget-proof__track"><span /></div><div className="budget-proof__bottom"><strong>$6.58 remaining</strong><span>Complete packages</span></div><small>Illustrative result using estimated complete-package catalog pricing.</small>
        </div>
      </section>

      <section className="product-story product-story--reuse"><div className="page-shell product-story__inner">
        <div className="reuse-visual" aria-label="Ingredients reused across meals">
          <div className="reuse-ingredient"><span>01</span><strong>Chicken</strong></div><div className="reuse-routes"><i /><i /><i /></div><div className="reuse-meals"><span>Burrito bowls</span><span>Quesadillas</span><span>Crispy wraps</span></div>
          <div className="reuse-ingredient reuse-ingredient--rice"><span>02</span><strong>Brown rice</strong></div><div className="reuse-routes reuse-routes--two"><i /><i /></div><div className="reuse-meals reuse-meals--two"><span>Burrito bowls</span><span>Rice bowls</span></div>
        </div>
        <div className="story-copy"><span className="story-number">02</span><p className="landing-eyebrow">One smarter basket</p><h2>Ingredients earn their place more than once.</h2><p>The week intentionally reuses the right groceries across different meals, helping reduce extra packages, wasted produce, and half-used ingredients.</p></div>
      </div></section>

      <section className="product-story product-story--swap page-shell">
        <div className="story-copy"><span className="story-number">03</span><p className="landing-eyebrow">Change a meal, not the whole plan</p><h2>Swap dinner. Keep the basket balanced.</h2><p>Every alternative is checked against the ingredients already in your basket and the total you asked Weektable to respect.</p></div>
        <div className="swap-proof" aria-label="Example meal swap"><div className="swap-proof__header"><span>MEAL SWAP</span><strong>Wednesday</strong></div><FoodImage mealId="turkey-rice-bowls" alt="Turkey rice bowls" className="swap-proof__image" /><div className="swap-proof__body"><span>NEW MEAL</span><h3>Turkey rice bowls</h3><p>Uses 4 ingredients already in your basket</p><div><strong>−$2.14</strong><span>New basket <b>$91.28</b></span></div></div></div>
      </section>

      <section className="groceries-story"><div className="page-shell groceries-story__inner">
        <div><p className="landing-eyebrow">Ready for the store</p><h2>One list. Real packages. A running total.</h2></div>
        <ul className="grocery-proof"><li><span className="grocery-check">✓</span><div><strong>Bell peppers</strong><small>2 × 3-count packages · Produce</small></div><b>$7.98</b></li><li><span className="grocery-check" /><div><strong>Chicken breast</strong><small>2 × about 2.25 lb · Meat</small></div><b>$23.96</b></li><li><span className="grocery-check" /><div><strong>Greek yogurt</strong><small>1 × 16 oz tub · Dairy & eggs</small></div><b>$4.29</b></li></ul>
      </div></section>

      <section className="landing-final page-shell"><FoodImage mealId="crispy-chicken-tacos" alt="Crispy chicken tacos ready for dinner" className="landing-final__photo" /><div><p className="landing-eyebrow">What’s for dinner this week?</p><h2>Give the week a budget. Get dinner handled.</h2><PlanLink /></div></section>

      <footer className="landing-footer"><div className="page-shell"><BrandMark /><p>Price estimates are planning tools. Verify current shelf prices and packaged-food labels.</p><nav aria-label="Legal"><Link href="/privacy">Privacy</Link> · <Link href="/terms">Terms</Link> · <Link href="/support">Support</Link></nav></div></footer>
    </main>
  );
}
