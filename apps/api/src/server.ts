import express from "express";
import cors from "cors";
import { asc } from "drizzle-orm";
import { db } from "./db/client.js";
import { activities } from "./db/schema.js";

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json());

app.get("/health", (_request, response) => {
  response.json({ status: "ok", service: "chronolog-api" });
});

app.get("/activities", async (_request, response) => {
  const rows = await db
    .select()
    .from(activities)
    .orderBy(asc(activities.createdAt));

  response.json(rows);
});

app.post("/activities", async (request, response) => {
  const name = typeof request.body.name === "string" ? request.body.name.trim() : "";
  const color = typeof request.body.color === "string" ? request.body.color.trim() : "";

  if (!name) {
    response.status(400).json({ error: "Activity name is required." });
    return;
  }

  if (!color) {
    response.status(400).json({ error: "Activity color is required." });
    return;
  }

  const [activity] = await db
    .insert(activities)
    .values({ name, color })
    .returning();

  response.status(201).json(activity);
});

app.listen(port, () => {
  console.log(`Chronolog API is running on http://localhost:${port}`);
});
