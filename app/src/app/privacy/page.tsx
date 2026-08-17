import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "Privacy · Weektable", description: "How Weektable processes planner and grocery data during the internal beta." };

export default function PrivacyPage() {
  return <main className="legal-page"><article className="legal-page__inner">
    <Link href="/">← Weektable</Link><p className="landing-eyebrow">Privacy</p><h1>Weektable privacy notice</h1>
    <p><strong>Operational draft · updated August 17, 2026.</strong> This plain-language notice describes the internal beta as implemented; it is not a claim of legal review.</p>
    <h2>Data we process</h2><p>Weektable processes your selected ZIP code and estimated-store choice, budget, household and dinner counts, leftover setting, food preferences, allergies, disliked foods, cuisines, pantry items, and custom instructions. The app also stores the generated plan, grocery ownership and checkoffs, and an anonymous device identifier used for abuse protection.</p>
    <h2>Why and where it is processed</h2><p>The backend uses this information to validate constraints, propose recipes, price estimated complete packages, build the grocery list, and perform swaps. When live planning is enabled, constrained recipe inputs are processed by OpenAI. Hosting and database providers process requests and stored plan records on our behalf.</p>
    <h2>Storage and logs</h2><p>Anonymous plan records and job state are retained for up to 14 days so generation and grocery progress can survive a restart. The iPhone keeps a local cached plan and planner draft until you remove the app or replace that data. Operational logs record safe categories, timing, and failure outcomes; complete allergy, ZIP-code, preference, and instruction payloads are redacted from structured logs.</p>
    <h2>Support</h2><p>Support requests include the email and message you submit and are retained for up to 30 days. Use the <Link href="/support">support form</Link> to ask for help or deletion of server-side beta data; include the relevant plan or support ticket identifier if available.</p>
    <h2>Advertising and sale</h2><p>Weektable does not use beta planner data for advertising and does not sell it. Do not put unnecessary sensitive or identifying information into custom instructions.</p>
    <h2>Safety</h2><p>Allergies are hard planning constraints against available metadata, but users must verify every package label. Cross-contact cannot be guaranteed. Nutrition is estimated and is not medical advice.</p>
  </article></main>;
}
