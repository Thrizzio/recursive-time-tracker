import express from "express";
import cors from "cors";
import { asc, desc, eq, inArray } from "drizzle-orm";
import { db } from "./db/client.js";
import { activities, activity_allocations, timeBlocks } from "./db/schema.js";

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(cors());
app.use(express.json());

// ─── Health ───────────────────────────────────────────────────────────────────

app.get("/health", (_request, response) => {
  response.json({ status: "ok", service: "chronolog-api" });
});

// ─── Activities ───────────────────────────────────────────────────────────────

app.get("/activities", async (_request, response) => {
  const rows = await db.select().from(activities).orderBy(asc(activities.createdAt));
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

  const [activity] = await db.insert(activities).values({ name, color }).returning();
  response.status(201).json(activity);
});

// ─── Time blocks  ─────────────────────────────────────────────────────────────

/**
 * POST /time-blocks
 *
 * Body: { allocations: Array<{ activityId: number; percentage: number }> }
 *
 * The backend is solely responsible for determining time.
 *  - start_time = end_time of the most recently created time block, OR
 *                 the server time of this very request if no block exists yet
 *                 (first-ever block; start = end = now, elapsed = 0)
 *  - end_time   = current server time (captured once at request start)
 *
 * On success returns the full time block with all allocations and their activity.
 */
app.post("/time-blocks", async (request, response) => {
  // ── 1. Parse and validate input ────────────────────────────────────────────

  const rawAllocations: unknown = request.body.allocations;

  if (!Array.isArray(rawAllocations) || rawAllocations.length === 0) {
    response.status(400).json({ error: "allocations must be a non-empty array." });
    return;
  }

  type RawAlloc = { activityId: unknown; percentage: unknown };
  const allocs = rawAllocations as RawAlloc[];

  // All entries must have integer activityId > 0 and integer percentage 0–100
  for (const alloc of allocs) {
    const id = Number(alloc.activityId);
    const pct = Number(alloc.percentage);

    if (!Number.isInteger(id) || id <= 0) {
      response.status(400).json({ error: `Invalid activityId: ${String(alloc.activityId)}.` });
      return;
    }
    if (!Number.isInteger(pct) || pct < 0 || pct > 100) {
      response.status(400).json({ error: `Percentage must be an integer between 0 and 100. Got ${String(alloc.percentage)}.` });
      return;
    }
  }

  const typedAllocs = allocs.map((a) => ({
    activityId: Number(a.activityId),
    percentage: Number(a.percentage),
  }));

  // Percentages must sum to exactly 100
  const totalPct = typedAllocs.reduce((sum, a) => sum + a.percentage, 0);
  if (totalPct !== 100) {
    response.status(400).json({
      error: `Allocation percentages must sum to 100. Got ${totalPct}.`,
    });
    return;
  }

  // All activityIds must exist in the DB
  const activityIds = typedAllocs.map((a) => a.activityId);
  const foundActivities = await db
    .select({ id: activities.id, name: activities.name, color: activities.color })
    .from(activities)
    .where(inArray(activities.id, activityIds));

  if (foundActivities.length !== activityIds.length) {
    const foundIds = new Set(foundActivities.map((a) => a.id));
    const missing = activityIds.filter((id) => !foundIds.has(id));
    response.status(404).json({ error: `Activity IDs not found: ${missing.join(", ")}.` });
    return;
  }

  const activityMap = Object.fromEntries(foundActivities.map((a) => [a.id, a]));

  // ── 2. Determine time boundaries (server side only) ────────────────────────

  const endTime = new Date(); // captured once — single source of truth for "now"

  // Find the most recent time block's end_time to use as our start
  const [latestBlock] = await db
    .select({ endTime: timeBlocks.endTime })
    .from(timeBlocks)
    .orderBy(desc(timeBlocks.endTime))
    .limit(1);

  // If no block exists yet, start_time = end_time (elapsed = 0, first block ever)
  const startTime = latestBlock ? latestBlock.endTime : endTime;
  const elapsedSeconds = Math.round((endTime.getTime() - startTime.getTime()) / 1000);

  // ── 3. Compute duration_seconds per allocation ────────────────────────────
  //
  // Computed in memory only — stored column is `percentage`.
  // Sum is guaranteed to equal elapsedSeconds by giving remainder to the
  // largest allocation.

  // Compute floor durations
  const durations = typedAllocs.map((a) => ({
    activityId: a.activityId,
    percentage: a.percentage,
    durationSeconds: Math.floor((a.percentage / 100) * elapsedSeconds),
  }));

  // Compute rounding remainder and assign it to the single largest allocation
  const sumFloor = durations.reduce((s, d) => s + d.durationSeconds, 0);
  const remainder = elapsedSeconds - sumFloor;
  if (remainder > 0) {
    // Find index of allocation with largest percentage (ties: first one wins)
    let largestIdx = 0;
    for (let i = 1; i < durations.length; i++) {
      if (durations[i].percentage > durations[largestIdx].percentage) largestIdx = i;
    }
    durations[largestIdx].durationSeconds += remainder;
  }

  // ── 4. Persist inside a transaction ───────────────────────────────────────

  try {
    const result = await db.transaction(async (tx) => {
      // Insert time block
      const [block] = await tx
        .insert(timeBlocks)
        .values({ startTime, endTime })
        .returning();

      // Insert all allocations
      const insertedAllocations = await tx
        .insert(activity_allocations)
        .values(
          typedAllocs.map((a) => ({
            timeBlockId: block.id,
            activityId: a.activityId,
            percentage: a.percentage,
          })),
        )
        .returning();

      return { block, insertedAllocations };
    });

    // ── 5. Build enriched response ────────────────────────────────────────

    const durationMap = Object.fromEntries(
      durations.map((d) => [d.activityId, d.durationSeconds]),
    );

    response.status(201).json({
      id: result.block.id,
      startTime: result.block.startTime,
      endTime: result.block.endTime,
      createdAt: result.block.createdAt,
      elapsedSeconds,
      allocations: result.insertedAllocations.map((alloc) => ({
        id: alloc.id,
        activityId: alloc.activityId,
        percentage: alloc.percentage,
        durationSeconds: durationMap[alloc.activityId] ?? 0,
        activity: activityMap[alloc.activityId],
      })),
    });
  } catch (err) {
    console.error("Failed to create time block:", err);
    response.status(500).json({ error: "Could not save time block. Please try again." });
  }
});

// ─── Server ───────────────────────────────────────────────────────────────────

app.listen(port, () => {
  console.log(`Chronolog API is running on http://localhost:${port}`);
});
