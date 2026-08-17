import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "Terms · Cove", description: "Terms for the Cove internal beta." };

export default function TermsPage() {
  return <main className="legal-page"><article className="legal-page__inner">
    <Link href="/">← Cove</Link><p className="landing-eyebrow">Terms</p><h1>Internal beta terms</h1>
    <p><strong>Operational draft · updated August 17, 2026.</strong> These terms describe the current internal beta and are not a claim of legal review.</p>
    <h2>Planning estimates</h2><p>Cove provides meal-planning information, estimated nutrition, and either provider-listed or estimated complete-package prices, as identified in the plan. It does not provide medical, dietary, or financial advice. Prices, package sizes, availability, nutrition, and labels can change; verify them before purchasing or eating a product.</p>
    <h2>Allergies and food safety</h2><p>Cove applies selected allergies as hard constraints using available recipe and catalog metadata. You remain responsible for checking labels, preparation conditions, recalls, and cross-contact warnings. Cove cannot guarantee allergen-free products or kitchens.</p>
    <h2>Beta availability</h2><p>The beta is provided without a paid subscription. Features may be unavailable, plans may expire, and the service may change while it is tested. Do not rely on it as the sole record of essential information.</p>
    <h2>Acceptable use</h2><p>Do not abuse the service, bypass rate limits, probe other users’ anonymous plans, upload unlawful content, or attempt to extract service credentials. We may restrict access needed to protect users, costs, and service reliability.</p>
    <h2>Questions</h2><p>Use the <Link href="/support">support form</Link> for questions about these terms or the beta.</p>
  </article></main>;
}
