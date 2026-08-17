import { DEMO_PRODUCTS } from "./fixtures";
import type { GroceryProvider, ProviderProduct, ProviderStore } from "./types";

const STORE_PREFIX = "cove-estimate";

function estimatedStore(zipCode: string, profile: "standard" | "value"): ProviderStore {
  const label = profile === "value" ? "Value grocery estimate" : "Standard grocery estimate";
  return {
    id: `${STORE_PREFIX}-${profile}-${zipCode}`,
    providerStoreId: `${STORE_PREFIX}-${profile}-${zipCode}`,
    name: label,
    retailer: "Cove estimate",
    address: `Planning estimate for ZIP ${zipCode}`,
    zipCode,
    priceKind: "estimated",
  };
}

function estimatedProducts(storeId: string): ProviderProduct[] {
  const profile = storeId.includes("-value-") ? "value" : "standard";
  const source = DEMO_PRODUCTS.filter((product) =>
    profile === "value" ? product.storeId.includes("value") : !product.storeId.includes("value"),
  );
  const observedAt = new Date().toISOString();
  return source.map((product) => ({
    ...product,
    id: `estimate-${profile}-${product.ingredientId}`,
    provider: "cove_estimate",
    providerProductId: `estimate-${profile}-${product.ingredientId}`,
    storeId,
    brand: "Cove category estimate",
    name: product.name.replace(/Kroger|Simple Truth|Private Selection|Murray's/gi, "Grocery"),
    salePriceCents: null,
    availability: "unknown",
    priceKind: "estimated",
    observedAt,
  }));
}

export const coveEstimateProvider: GroceryProvider = {
  id: "cove_estimate",
  displayName: "Cove estimated pricing",
  async findStores(zipCode) {
    return [estimatedStore(zipCode, "standard"), estimatedStore(zipCode, "value")];
  },
  async searchProducts({ storeId, ingredientId }) {
    return estimatedProducts(storeId).filter((product) => product.ingredientId === ingredientId);
  },
  async getProduct({ storeId, productId }) {
    return estimatedProducts(storeId).find((product) => product.id === productId) ?? null;
  },
};

export function isCoveEstimateStore(storeId: string) {
  return storeId.startsWith(STORE_PREFIX);
}
