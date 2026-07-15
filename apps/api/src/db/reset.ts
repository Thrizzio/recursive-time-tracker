import "dotenv/config";
import { Pool } from "pg";

if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL is required.");
}

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function reset() {
    const client = await pool.connect();
    try {
        console.log("Dropping public schema...");
        await client.query("DROP SCHEMA public CASCADE");
        await client.query("CREATE SCHEMA public");
        console.log("Public schema recreated. All tables have been wiped.");
    } finally {
        client.release();
        await pool.end();
    }
}

reset().catch((err) => {
    console.error(err);
    process.exit(1);
});
