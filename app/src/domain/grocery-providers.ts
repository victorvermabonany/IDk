import "server-only";

import { coveEstimateProvider, isCoveEstimateStore } from "./cove-estimate-provider";
import { fixtureGroceryProvider } from "./fixture-provider";
import { krogerConfigured, krogerProvider } from "./kroger-provider";
import type { GroceryProvider, ProviderStore } from "./types";
import { runtimeMode } from "@/server/runtime-config";

export async function availableStores(postalCode: string): Promise<ProviderStore[]> {
  if (runtimeMode() === "development_fixture") return fixtureGroceryProvider.findStores(postalCode);
  const estimates = await coveEstimateProvider.findStores(postalCode);
  if (!krogerConfigured()) return estimates;
  try { return [...await krogerProvider.findStores(postalCode), ...estimates]; }
  catch { return estimates; }
}

export function providerForStore(store: { id: string; locationId: string }): GroceryProvider {
  if (store.id.startsWith("kroger-") || /^\d+$/.test(store.locationId)) {
    if (!krogerConfigured()) throw new Error("Kroger pricing is not configured.");
    return krogerProvider;
  }
  if (isCoveEstimateStore(store.id) || isCoveEstimateStore(store.locationId)) return coveEstimateProvider;
  if (runtimeMode() === "development_fixture") return fixtureGroceryProvider;
  throw new Error("Fixture stores are not permitted outside explicit development fixture mode.");
}

export function groceryProviderStatus() {
  return { estimates: "ready" as const, kroger: krogerConfigured() ? "configured" as const : "not_configured" as const };
}
