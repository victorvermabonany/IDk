import fs from "node:fs/promises";
import path from "node:path";
import postgres from "postgres";

const databaseURL = process.env.DATABASE_URL;
if (!databaseURL || (!databaseURL.startsWith("postgres://") && !databaseURL.startsWith("postgresql://"))) {
  throw new Error("DATABASE_URL must be a PostgreSQL connection string.");
}

const migrationsDirectory = path.resolve(process.cwd(), "db", "migrations");
const migrationFiles = (await fs.readdir(migrationsDirectory)).filter((name) => /^\d+.*\.sql$/.test(name)).sort();
const sql = postgres(databaseURL, { max: 1, connect_timeout: 10, idle_timeout: 5 });

try {
  await sql`CREATE TABLE IF NOT EXISTS cove_schema_migrations (
    name text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
  )`;
  for (const name of migrationFiles) {
    const existing = await sql`SELECT name FROM cove_schema_migrations WHERE name = ${name}`;
    if (existing.length > 0) continue;
    const contents = await fs.readFile(path.join(migrationsDirectory, name), "utf8");
    await sql.begin(async (transaction) => {
      await transaction.unsafe(contents);
      await transaction`INSERT INTO cove_schema_migrations (name) VALUES (${name})`;
    });
    console.info(`Applied ${name}`);
  }
} finally {
  await sql.end({ timeout: 5 });
}
