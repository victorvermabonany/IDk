import "server-only";

import { PlanGenerationError, type Department, type GroceryProvider, type ProviderProduct, type ProviderStore, type Unit } from "./types";

const API_BASE = "https://api.kroger.com/v1";
const TOKEN_URL = `${API_BASE}/connect/oauth2/token`;
const REQUEST_TIMEOUT_MS = 10_000;

interface KrogerConfig { clientId: string; clientSecret: string; }
interface KrogerLocationResponse { data?: Array<{ locationId?: string; name?: string; chain?: string; address?: { addressLine1?: string; city?: string; state?: string; zipCode?: string } }> }
interface KrogerProductResponse { data?: KrogerProductRecord | KrogerProductRecord[] }
interface KrogerProductRecord {
  productId?: string; upc?: string; description?: string; brand?: string; categories?: string[];
  items?: Array<{ size?: string; price?: { regular?: number; promo?: number }; inventory?: { stockLevel?: string } }>;
}

let tokenCache: { value: string; expiresAt: number } | undefined;

function configuration(): KrogerConfig | null {
  const clientId = process.env.KROGER_CLIENT_ID?.trim();
  const clientSecret = process.env.KROGER_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) return null;
  return { clientId, clientSecret };
}

export function krogerConfigured() { return configuration() !== null; }

async function accessToken() {
  if (tokenCache && tokenCache.expiresAt > Date.now() + 30_000) return tokenCache.value;
  const config = configuration();
  if (!config) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger pricing is not configured.");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: {
        authorization: `Basic ${Buffer.from(`${config.clientId}:${config.clientSecret}`).toString("base64")}`,
        "content-type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ grant_type: "client_credentials", scope: "product.compact" }),
      cache: "no-store",
      signal: controller.signal,
    });
    if (!response.ok) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger authorization is temporarily unavailable.");
    const payload = await response.json() as { access_token?: string; expires_in?: number };
    if (!payload.access_token) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger authorization returned an incomplete response.");
    tokenCache = { value: payload.access_token, expiresAt: Date.now() + Math.max(60, payload.expires_in ?? 1_800) * 1_000 };
    return tokenCache.value;
  } catch (error) {
    if (error instanceof PlanGenerationError) throw error;
    throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger authorization timed out or could not be reached.");
  } finally { clearTimeout(timeout); }
}

async function krogerRequest<T>(path: string): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${API_BASE}${path}`, {
      headers: { authorization: `Bearer ${await accessToken()}`, accept: "application/json" },
      cache: "no-store",
      signal: controller.signal,
    });
    if (response.status === 429) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger request capacity was reached. Please try again shortly.");
    if (!response.ok) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger product data is temporarily unavailable.");
    return await response.json() as T;
  } catch (error) {
    if (error instanceof PlanGenerationError) throw error;
    throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Kroger product data timed out or could not be reached.");
  } finally { clearTimeout(timeout); }
}

function packageDetails(size: string | undefined): { quantity: number; unit: Unit; display: string } {
  const display = size?.trim() || "1 count";
  const match = display.match(/([0-9]+(?:\.[0-9]+)?)\s*(fl\s*oz|oz|lb|ct|count)/i);
  if (!match) return { quantity: 1, unit: "count", display };
  const normalized = match[2].toLowerCase().replace(/\s+/g, " ");
  const unit: Unit = normalized === "fl oz" ? "fl_oz" : normalized === "ct" ? "count" : normalized as Unit;
  return { quantity: Number(match[1]), unit, display };
}

function department(categories: string[] | undefined): Department {
  const value = (categories ?? []).join(" ").toLowerCase();
  if (/produce|fruit|vegetable/.test(value)) return "Produce";
  if (/meat|seafood/.test(value)) return "Meat";
  if (/dairy|egg/.test(value)) return "Dairy & eggs";
  if (/bakery|bread/.test(value)) return "Bakery";
  if (/canned/.test(value)) return "Canned goods";
  if (/spice|season/.test(value)) return "Seasonings";
  if (/pantry|pasta|grain|sauce/.test(value)) return "Pantry";
  return "Other";
}

function normalizeProduct(record: KrogerProductRecord, storeId: string, ingredientId: string): ProviderProduct | null {
  const item = record.items?.find((candidate) => candidate.price?.regular || candidate.price?.promo);
  const productId = record.productId ?? record.upc;
  const regular = item?.price?.regular;
  if (!productId || !record.description || typeof regular !== "number") return null;
  const packageInfo = packageDetails(item?.size);
  const stockLevel = item?.inventory?.stockLevel?.toLowerCase() ?? "";
  return {
    id: `kroger-${productId}`,
    ingredientId,
    provider: "kroger",
    providerProductId: productId,
    storeId,
    name: record.description,
    brand: record.brand ?? "Kroger catalog",
    displayPackage: packageInfo.display,
    packageQuantity: packageInfo.quantity,
    packageUnit: packageInfo.unit,
    regularPriceCents: Math.round(regular * 100),
    salePriceCents: typeof item?.price?.promo === "number" ? Math.round(item.price.promo * 100) : null,
    availability: /out/.test(stockLevel) ? "out_of_stock" : stockLevel ? "in_stock" : "unknown",
    department: department(record.categories),
    priceKind: "live",
    observedAt: new Date().toISOString(),
  };
}

export const krogerProvider: GroceryProvider = {
  id: "kroger",
  displayName: "Kroger",
  async findStores(zipCode) {
    if (!krogerConfigured()) return [];
    const payload = await krogerRequest<KrogerLocationResponse>(`/locations?${new URLSearchParams({ "filter.zipCode.near": zipCode, "filter.limit": "10" })}`);
    return (payload.data ?? []).flatMap((location): ProviderStore[] => {
      if (!location.locationId) return [];
      const address = location.address;
      return [{
        id: `kroger-${location.locationId}`,
        providerStoreId: location.locationId,
        name: location.name ?? location.chain ?? "Kroger family store",
        retailer: location.chain ?? "Kroger",
        address: [address?.addressLine1, address?.city, address?.state, address?.zipCode].filter(Boolean).join(", "),
        zipCode: address?.zipCode?.slice(0, 5) ?? zipCode,
        priceKind: "live",
      }];
    });
  },
  async searchProducts({ storeId, ingredientId }) {
    const locationId = storeId.replace(/^kroger-/, "");
    const payload = await krogerRequest<KrogerProductResponse>(`/products?${new URLSearchParams({ "filter.term": ingredientId.replaceAll("_", " "), "filter.locationId": locationId, "filter.limit": "10" })}`);
    const records = Array.isArray(payload.data) ? payload.data : payload.data ? [payload.data] : [];
    return records.flatMap((record) => {
      const product = normalizeProduct(record, storeId, ingredientId);
      return product ? [product] : [];
    });
  },
  async getProduct({ storeId, productId }) {
    const locationId = storeId.replace(/^kroger-/, "");
    const id = productId.replace(/^kroger-/, "");
    const payload = await krogerRequest<KrogerProductResponse>(`/products/${encodeURIComponent(id)}?${new URLSearchParams({ "filter.locationId": locationId })}`);
    const record = Array.isArray(payload.data) ? payload.data[0] : payload.data;
    return record ? normalizeProduct(record, storeId, "unknown") : null;
  },
};
