import "server-only";

export class PremiumAccessError extends Error {
  readonly code = "PREMIUM_REQUIRED";
  constructor(public readonly feature: "another_week" | "additional_swap") {
    super(feature === "another_week"
      ? "Your first complete week is yours. Cove Pro unlocks additional weeks."
      : "Your first meal swap is included. Cove Pro unlocks additional swaps.");
    this.name = "PremiumAccessError";
  }
}

export function hasActiveProEntitlement(status: string, expiresAt?: Date | null) {
  return status === "pro" && (!expiresAt || expiresAt > new Date());
}
