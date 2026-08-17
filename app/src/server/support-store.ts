import "server-only";

import { randomUUID } from "node:crypto";
import postgres, { type Sql } from "postgres";
import { productionConfig, runtimeMode } from "@/server/runtime-config";

let sql: Sql | undefined;
const developmentTickets: { id: string; contactEmail: string; message: string; createdAt: string }[] = [];

export async function createSupportTicket(contactEmail: string, message: string) {
  const ticket = { id: randomUUID(), contactEmail, message, createdAt: new Date().toISOString() };
  if (runtimeMode() === "development_fixture") { developmentTickets.push(ticket); return ticket.id; }
  sql ??= postgres(productionConfig().DATABASE_URL, { max: 3, idle_timeout: 20, connect_timeout: 10 });
  await sql`DELETE FROM weektable_support_requests WHERE expires_at < now()`;
  await sql`INSERT INTO weektable_support_requests (id, contact_email, message, expires_at)
    VALUES (${ticket.id}, ${ticket.contactEmail}, ${ticket.message}, ${new Date(Date.now() + 30 * 86_400_000)})`;
  return ticket.id;
}
