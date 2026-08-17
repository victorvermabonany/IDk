import type { Unit } from "@/domain/types";

export function formatMoney(cents: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(cents / 100);
}

export function formatQuantity(quantity: number, unit: Unit) {
  if (unit === "oz" && quantity >= 16) {
    const pounds = quantity / 16;
    return `${Number(pounds.toFixed(2))} lb`;
  }
  if (unit === "fl_oz" && quantity < 1) return `${Number((quantity * 6).toFixed(2))} tsp`;
  if (unit === "fl_oz" && quantity < 4) return `${Number((quantity * 2).toFixed(2))} tbsp`;
  if (unit === "fl_oz") return `${Number(quantity.toFixed(2))} fl oz`;
  return `${Number(quantity.toFixed(2))} ${unit}`;
}

export function formatDelta(cents: number) {
  if (cents === 0) return "$0.00 change";
  return `${cents > 0 ? "+" : "−"}${formatMoney(Math.abs(cents))}`;
}
