import type { Metadata } from "next";
import Link from "next/link";
import { SupportForm } from "./support-form";

export const metadata: Metadata = { title: "Support · Weektable", description: "Contact Weektable support about the internal beta." };

export default function SupportPage() {
  return <main className="legal-page"><div className="legal-page__inner">
    <Link href="/">← Weektable</Link><p className="landing-eyebrow">Support</p><h1>How can we help?</h1>
    <p>Send a support request with an email address where we can follow up. Please do not include passwords, payment details, or unnecessary medical information.</p>
    <SupportForm />
    <p className="legal-note">Support requests are retained for up to 30 days while we investigate and respond.</p>
  </div></main>;
}
