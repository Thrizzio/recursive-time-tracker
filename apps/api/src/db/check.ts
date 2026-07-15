import "dotenv/config";
import { Pool } from "pg";

const pool = new Pool({ connectionString: process.env.DATABASE_URL! });

async function check() {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name;
    `);
    console.log("Tables in public schema:");
    if (result.rows.length === 0) {
      console.log("  (none — schema is empty)");
    } else {
      result.rows.forEach((row) => console.log(" ", row.table_name));
    }
  } finally {
    client.release();
    await pool.end();
  }
}

check().catch((err) => {
  console.error("Connection failed:", err.message);
  process.exit(1);
});
