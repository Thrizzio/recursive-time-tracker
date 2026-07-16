import "dotenv/config";
import { Pool } from "pg";

const pool = new Pool({ connectionString: process.env.DATABASE_URL! });

async function push() {
  const client = await pool.connect();
  try {
    console.log("Resetting schema and recreating tables...");

    await client.query(`DROP TABLE IF EXISTS "activity_allocations" CASCADE`);
    await client.query(`DROP TABLE IF EXISTS "time_blocks" CASCADE`);
    await client.query(`DROP TABLE IF EXISTS "activities" CASCADE`);
    await client.query(`DROP TABLE IF EXISTS "sessions" CASCADE`);
    await client.query(`DROP TABLE IF EXISTS "users" CASCADE`);

    await client.query(`
      CREATE TABLE "users" (
        "id" serial PRIMARY KEY NOT NULL,
        "google_id" varchar(255) NOT NULL UNIQUE,
        "email" varchar(255) NOT NULL,
        "name" varchar(255) NOT NULL,
        "avatar_url" text,
        "created_at" timestamp with time zone DEFAULT now() NOT NULL
      );
    `);
    console.log("  ✓ users");

    await client.query(`
      CREATE TABLE "sessions" (
        "id" text PRIMARY KEY NOT NULL,
        "user_id" integer NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "expires_at" timestamp with time zone NOT NULL
      );
    `);
    console.log("  ✓ sessions");

    await client.query(`
      CREATE TABLE "activities" (
        "id" serial PRIMARY KEY NOT NULL,
        "user_id" integer NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "name" varchar(100) NOT NULL,
        "color" varchar(20) NOT NULL,
        "created_at" timestamp with time zone DEFAULT now() NOT NULL
      );
    `);
    console.log("  ✓ activities");

    await client.query(`
      CREATE TABLE "time_blocks" (
        "id" serial PRIMARY KEY NOT NULL,
        "user_id" integer NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "start_time" timestamp with time zone NOT NULL,
        "end_time" timestamp with time zone NOT NULL,
        "created_at" timestamp with time zone DEFAULT now() NOT NULL
      );
    `);
    console.log("  ✓ time_blocks");

    await client.query(`
      CREATE TABLE "activity_allocations" (
        "id" serial PRIMARY KEY NOT NULL,
        "time_block_id" integer NOT NULL REFERENCES "time_blocks"("id") ON DELETE CASCADE,
        "activity_id" integer NOT NULL REFERENCES "activities"("id") ON DELETE CASCADE,
        "percentage" integer NOT NULL
      );
    `);
    console.log("  ✓ activity_allocations");

    console.log("\nAll tables created successfully.");
  } finally {
    client.release();
    await pool.end();
  }
}

push().catch((err) => {
  console.error("Failed:", err.message);
  process.exit(1);
});
