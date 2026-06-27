import express from "express";
import cors from "cors";
import { asc, eq } from "drizzle-orm";
import { db } from "./db/client.js";
import { activities, timeLogs } from "./db/schema.js";

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

app.get("/time-logs", async (_request, response) => {
  const rows = await db
    .select({
      id: timeLogs.id,
      activityId: timeLogs.activityId,
      loggedAt: timeLogs.loggedAt,
      createdAt: timeLogs.createdAt,
      activity: {
        id: activities.id,
        name: activities.name,
        color: activities.color,
      },
    })
    .from(timeLogs)
    .innerJoin(activities, eq(timeLogs.activityId, activities.id))
    .orderBy(asc(timeLogs.loggedAt));

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

app.post("/time-logs", async (request, response) => {
  const activityId = Number(request.body.activityId);

  if (!Number.isInteger(activityId) || activityId <= 0) {
    response.status(400).json({ error: "A valid activityId is required." });
    return;
  }

  const [existingActivity] = await db
    .select({ id: activities.id })
    .from(activities)
    .where(eq(activities.id, activityId))
    .limit(1);

  if (!existingActivity) {
    response.status(404).json({ error: "Activity not found." });
    return;
  }

  const [timeLog] = await db.insert(timeLogs).values({ activityId }).returning();

  response.status(201).json(timeLog);
});

app.listen(port, () => {
  console.log(`Chronolog API is running on http://localhost:${port}`);
});
