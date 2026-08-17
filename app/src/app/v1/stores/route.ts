import { availableStores } from "@/domain/grocery-providers";
import { problemResponse } from "@/server/http";
import { guardRequest } from "@/server/request-guard";

export async function GET(request: Request) {
  try {
    guardRequest(request, 30, 60_000);
    const postalCode = new URL(request.url).searchParams.get("postalCode") ?? "";
    if (!/^\d{5}$/.test(postalCode)) return Response.json({ error: { code: "INVALID_POSTAL_CODE", message: "Enter a five-digit ZIP code." } }, { status: 400 });
    return Response.json({ stores: await availableStores(postalCode) });
  } catch (error) { return problemResponse(error); }
}
