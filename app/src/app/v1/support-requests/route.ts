import { z } from "zod";
import { problemResponse } from "@/server/http";
import { guardRequest, readJSONBody } from "@/server/request-guard";
import { createSupportTicket } from "@/server/support-store";

const supportRequestSchema = z.object({
  contactEmail: z.string().trim().email().max(254),
  message: z.string().trim().min(10).max(2_000),
});

export async function POST(request: Request) {
  try {
    guardRequest(request, 4, 15 * 60_000);
    const input = supportRequestSchema.strict().parse(await readJSONBody(request));
    const ticketID = await createSupportTicket(input.contactEmail, input.message);
    return Response.json({ ticketId: ticketID }, { status: 201 });
  } catch (error) { return problemResponse(error); }
}
