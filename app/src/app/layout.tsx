import type { Metadata } from "next";
import { DM_Sans, Newsreader } from "next/font/google";
import "./globals.css";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
});

const newsreader = Newsreader({
  variable: "--font-newsreader",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  title: "Cove — Your week, planned.",
  description:
    "Tell Cove where you shop, what you want to spend, and how you like to eat. Get a week of dinners and one grocery list built around it.",
  applicationName: "Cove",
  openGraph: {
    title: "Cove — Your week, planned.",
    description: "A week of dinners and one grocery list built around your store, budget, and food preferences.",
    type: "website",
    siteName: "Cove",
    images: [{ url: "/weektable-dinners.png", width: 1536, height: 1024, alt: "A Cove week of approachable dinners" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Cove — Your week, planned.",
    description: "A week of dinners and one grocery list built around your store, budget, and food preferences.",
    images: ["/weektable-dinners.png"],
  },
  icons: { icon: "/favicon.ico", apple: "/weektable-app-icon.png" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${dmSans.variable} ${newsreader.variable}`} data-scroll-behavior="smooth">
      <body>{children}</body>
    </html>
  );
}
