import { sql } from "drizzle-orm";
import { db, pool } from "./client.js";

try {
  const result = await db.execute(sql`select current_database() as database_name`);
  const databaseName = result.rows[0]?.database_name;

  console.log(`Connected to PostgreSQL database: ${databaseName}`);
} catch (error) {
  console.error("Could not connect to PostgreSQL.");
  console.error("Check apps/api/.env and make sure DATABASE_URL uses your local PostgreSQL username, password, host, port, and database name.");

  const cause = error instanceof Error ? error.cause : undefined;

  if (cause instanceof Error) {
    console.error(`Reason: ${cause.message}`);
  } else if (error instanceof Error) {
    console.error(`Reason: ${error.message}`);
  }

  process.exitCode = 1;
} finally {
  await pool.end();
}
