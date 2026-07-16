import express from "express";
import cors from "cors";
import cookieParser from "cookie-parser";
import { asc, desc, eq, inArray, and } from "drizzle-orm";
import { db } from "./db/client.js";
import { activities, activity_allocations, timeBlocks, users } from "./db/schema.js";
import { getGoogleAuthUrl, getGoogleTokens, getGoogleUser } from "./auth/google.js";
import { createSession, getSessionUserId, deleteSession } from "./auth/session.js";

const app = express();
const port = Number(process.env.PORT) || 3000;

app.use(cors({
  origin: process.env.VITE_WEB_URL ?? "http://localhost:5173",
  credentials: true,
}));
app.use(express.json());
app.use(cookieParser());

// ─── Health ───────────────────────────────────────────────────────────────────

app.get("/health", (_request, response) => {
  response.json({ status: "ok", service: "chronolog-api" });
});

// ─── Auth Middleware ──────────────────────────────────────────────────────────

async function requireAuth(req: express.Request, res: express.Response, next: express.NextFunction) {
  const sessionId = req.cookies.chronolog_session;
  if (!sessionId) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  const userId = await getSessionUserId(sessionId);
  if (!userId) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  res.locals.userId = userId;
  next();
}

// ─── Auth Routes ──────────────────────────────────────────────────────────────

app.get("/auth/google", (req, res) => {
  res.redirect(getGoogleAuthUrl());
});

app.get("/auth/google/callback", async (req, res) => {
  const code = req.query.code as string;
  if (!code) {
    res.status(400).send("No code provided");
    return;
  }

  try {
    const tokens = await getGoogleTokens(code);
    const googleUser = await getGoogleUser(tokens.id_token, tokens.access_token);

    let [user] = await db.select().from(users).where(eq(users.googleId, googleUser.id));
    if (!user) {
      [user] = await db.insert(users).values({
        googleId: googleUser.id,
        email: googleUser.email,
        name: googleUser.name,
        avatarUrl: googleUser.picture,
      }).returning();
    } else {
      [user] = await db.update(users).set({
        name: googleUser.name,
        avatarUrl: googleUser.picture,
      }).where(eq(users.id, user.id)).returning();
    }

    const sessionId = await createSession(user.id);

    res.cookie("chronolog_session", sessionId, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      maxAge: 30 * 24 * 60 * 60 * 1000,
      path: "/",
    });

    res.redirect(process.env.VITE_WEB_URL ?? "http://localhost:5173");
  } catch (error) {
    console.error("Auth callback error:", error);
    res.status(500).send("Authentication failed");
  }
});

app.get("/auth/me", requireAuth, async (req, res) => {
  const userId = res.locals.userId;
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  res.json({ id: user.id, email: user.email, name: user.name, avatarUrl: user.avatarUrl });
});

app.post("/auth/logout", async (req, res) => {
  const sessionId = req.cookies.chronolog_session;
  if (sessionId) {
    await deleteSession(sessionId);
  }
  res.clearCookie("chronolog_session");
  res.json({ success: true });
});

// ─── Activities ───────────────────────────────────────────────────────────────

app.get("/activities", requireAuth, async (_request, response) => {
  const userId = response.locals.userId;
  const rows = await db
    .select()
    .from(activities)
    .where(eq(activities.userId, userId))
    .orderBy(asc(activities.createdAt));
  response.json(rows);
});

app.post("/activities", requireAuth, async (request, response) => {
  const userId = response.locals.userId;
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

  const [activity] = await db.insert(activities).values({ userId, name, color }).returning();
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
app.post("/time-blocks", requireAuth, async (request, response) => {
  // ── 1. Parse and validate input ────────────────────────────────────────────
  const userId = response.locals.userId;

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

  // All activityIds must exist in the DB and belong to the user
  const activityIds = typedAllocs.map((a) => a.activityId);
  const foundActivities = await db
    .select({ id: activities.id, name: activities.name, color: activities.color })
    .from(activities)
    .where(and(
      eq(activities.userId, userId),
      inArray(activities.id, activityIds)
    ));

  if (foundActivities.length !== activityIds.length) {
    const foundIds = new Set(foundActivities.map((a) => a.id));
    const missing = activityIds.filter((id) => !foundIds.has(id));
    response.status(404).json({ error: `Activity IDs not found or access denied: ${missing.join(", ")}.` });
    return;
  }

  const activityMap = Object.fromEntries(foundActivities.map((a) => [a.id, a]));

  // ── 2. Determine time boundaries (server side only) ────────────────────────

  const endTime = new Date(); // captured once — single source of truth for "now"

  // Find the most recent time block's end_time for THIS user
  const [latestBlock] = await db
    .select({ endTime: timeBlocks.endTime })
    .from(timeBlocks)
    .where(eq(timeBlocks.userId, userId))
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
        .values({ userId, startTime, endTime })
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

// ─── GET /time-blocks ────────────────────────────────────────────────────────
//
// Returns all time blocks with their allocations and activity details.
// A single three-way join avoids N+1.  Rows are grouped in memory.
// Ordered newest first (desc by start_time).

app.get("/time-blocks", requireAuth, async (request, response) => {
  const userId = response.locals.userId;
  try {
    // One query — left join so a block with no allocations still appears
    const rows = await db
      .select({
        blockId: timeBlocks.id,
        blockStartTime: timeBlocks.startTime,
        blockEndTime: timeBlocks.endTime,
        blockCreatedAt: timeBlocks.createdAt,
        allocId: activity_allocations.id,
        allocPct: activity_allocations.percentage,
        actId: activities.id,
        actName: activities.name,
        actColor: activities.color,
      })
      .from(timeBlocks)
      .where(eq(timeBlocks.userId, userId))
      .leftJoin(
        activity_allocations,
        eq(activity_allocations.timeBlockId, timeBlocks.id),
      )
      .leftJoin(
        activities,
        eq(activities.id, activity_allocations.activityId),
      )
      .orderBy(desc(timeBlocks.startTime));

    // Group flat rows → hierarchical blocks
    const blockMap = new Map<number, {
      id: number;
      startTime: Date;
      endTime: Date;
      createdAt: Date;
      elapsedSeconds: number;
      allocations: Array<{
        id: number;
        activityId: number;
        percentage: number;
        durationSeconds: number;
        activity: { id: number; name: string; color: string };
      }>;
    }>();

    for (const row of rows) {
      if (!blockMap.has(row.blockId)) {
        const elapsed = Math.round(
          (row.blockEndTime.getTime() - row.blockStartTime.getTime()) / 1000,
        );
        blockMap.set(row.blockId, {
          id: row.blockId,
          startTime: row.blockStartTime,
          endTime: row.blockEndTime,
          createdAt: row.blockCreatedAt,
          elapsedSeconds: elapsed,
          allocations: [],
        });
      }

      // A block might legitimately have no allocations (left join returns nulls)
      if (row.allocId !== null && row.actId !== null) {
        const block = blockMap.get(row.blockId)!;
        const durationSeconds = Math.round(
          ((row.allocPct ?? 0) / 100) * block.elapsedSeconds,
        );
        block.allocations.push({
          id: row.allocId,
          activityId: row.actId,
          percentage: row.allocPct ?? 0,
          durationSeconds,
          activity: { id: row.actId, name: row.actName!, color: row.actColor! },
        });
      }
    }

    // Already in desc(startTime) order from the query; Map preserves insertion order
    response.json([...blockMap.values()]);
  } catch (err) {
    console.error("Failed to fetch time blocks:", err);
    response.status(500).json({ error: "Could not fetch time blocks." });
  }
});

// ─── Server ───────────────────────────────────────────────────────────────────

app.listen(port, () => {
  console.log(`Chronolog API is running on http://localhost:${port}`);
});
