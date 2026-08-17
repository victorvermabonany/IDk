import { DEMO_PRODUCTS, DEMO_STORES } from "./fixtures";
import type { GroceryProvider } from "./types";

export const fixtureGroceryProvider: GroceryProvider = {
  id: "fixture",
  displayName: "Weektable estimated catalog",
  async findStores(zipCode) {
    return DEMO_STORES.map((store) => ({ ...store, zipCode, address: `Cincinnati, OH ${zipCode}` }));
  },
  async searchProducts({ storeId, ingredientId }) {
    return DEMO_PRODUCTS.filter(
      (product) => product.storeId === storeId && product.ingredientId === ingredientId,
    );
  },
  async getProduct({ storeId, productId }) {
    return (
      DEMO_PRODUCTS.find(
        (product) => product.storeId === storeId && product.id === productId,
      ) ?? null
    );
  },
};
