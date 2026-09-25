import { and, desc, eq, inArray } from "drizzle-orm";
import { db, pool } from "../db/client.js";
import { pomodoroPlans } from "../db/schema.js";

export type PomodoroStatus =
  | "focus"
  | "shortBreak"
  | "longBreak"
  | "paused"
  | "completed"
  | "cancelled";

export type PomodoroPhase = "focus" | "shortBreak" | "longBreak";

export interface PomodoroStartParams {
  totalSessions?: number;
  focusDurationSeconds?: number;
  shortBreakDurationSeconds?: number;
  longBreakDurationSeconds?: number;
  longBreakInterval?: number;
  autoStartBreaks?: boolean;
  autoStartFocus?: boolean;
  taskId?: string;
  taskTitle?: string;
}

export type PomodoroPlan = typeof pomodoroPlans.$inferSelect;

export interface PomodoroPlanState {
  status: PomodoroStatus;
  currentPhase: PomodoroPhase;
  currentSession: number;
  totalSessions: number;
  focusDurationSeconds: number;
  shortBreakDurationSeconds: number;
  longBreakDurationSeconds: number;
  longBreakInterval: number;
  autoStartBreaks: boolean;
  autoStartFocus: boolean;
  phaseStartedAt: Date | null;
  phaseEndsAt: Date | null;
  pausedAt: Date | null;
  pausedRemainingSeconds: number | null;
  totalFocusSeconds: number;
  totalBreakSeconds: number;
  totalPausedSeconds: number;
  completedSessions: number;
  completedAt: Date | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure State Machine & Time Accounting Transitions
// ─────────────────────────────────────────────────────────────────────────────

export function calculatePauseTransition(
  plan: PomodoroPlanState,
  now: Date
): Partial<PomodoroPlanState> {
  if (plan.status === "paused") {
    return {};
  }

  let remainingSeconds = 0;
  let elapsedPhaseSeconds = 0;

  if (plan.phaseEndsAt) {
    remainingSeconds = Math.max(
      0,
      Math.floor((plan.phaseEndsAt.getTime() - now.getTime()) / 1000)
    );
  }
  if (plan.phaseStartedAt) {
    elapsedPhaseSeconds = Math.max(
      0,
      Math.floor((now.getTime() - plan.phaseStartedAt.getTime()) / 1000)
    );
  }

  let addFocus = 0;
  let addBreak = 0;
  if (plan.currentPhase === "focus") {
    addFocus = elapsedPhaseSeconds;
  } else {
    addBreak = elapsedPhaseSeconds;
  }

  return {
    status: "paused",
    pausedAt: now,
    pausedRemainingSeconds: remainingSeconds,
    totalFocusSeconds: plan.totalFocusSeconds + addFocus,
    totalBreakSeconds: plan.totalBreakSeconds + addBreak,
  };
}

export function calculateResumeTransition(
  plan: PomodoroPlanState,
  now: Date
): Partial<PomodoroPlanState> {
  if (plan.status !== "paused") {
    return {};
  }

  let elapsedPaused = 0;
  if (plan.pausedAt) {
    elapsedPaused = Math.max(
      0,
      Math.floor((now.getTime() - plan.pausedAt.getTime()) / 1000)
    );
  }

  const remainingSeconds =
    plan.pausedRemainingSeconds && plan.pausedRemainingSeconds > 0
      ? plan.pausedRemainingSeconds
      : plan.currentPhase === "focus"
      ? plan.focusDurationSeconds
      : plan.currentPhase === "longBreak"
      ? plan.longBreakDurationSeconds
      : plan.shortBreakDurationSeconds;

  const phaseEndsAt = new Date(now.getTime() + remainingSeconds * 1000);

  return {
    status: plan.currentPhase,
    phaseStartedAt: now,
    phaseEndsAt,
    pausedAt: null,
    pausedRemainingSeconds: null,
    totalPausedSeconds: plan.totalPausedSeconds + elapsedPaused,
  };
}

export function calculateNextTransition(
  plan: PomodoroPlanState,
  now: Date
): Partial<PomodoroPlanState> {
  let addFocus = 0;
  let addBreak = 0;
  let addPaused = 0;

  if (plan.status === "paused" && plan.pausedAt) {
    addPaused = Math.max(
      0,
      Math.floor((now.getTime() - plan.pausedAt.getTime()) / 1000)
    );
  } else if (plan.phaseStartedAt) {
    const elapsed = Math.max(
      0,
      Math.floor((now.getTime() - plan.phaseStartedAt.getTime()) / 1000)
    );
    if (plan.currentPhase === "focus") {
      addFocus = elapsed;
    } else {
      addBreak = elapsed;
    }
  }

  const newTotalFocus = plan.totalFocusSeconds + addFocus;
  const newTotalBreak = plan.totalBreakSeconds + addBreak;
  const newTotalPaused = plan.totalPausedSeconds + addPaused;

  if (plan.currentPhase === "focus") {
    const newCompletedSessions = plan.completedSessions + 1;

    if (newCompletedSessions >= plan.totalSessions) {
      return {
        status: "completed",
        completedSessions: newCompletedSessions,
        totalFocusSeconds: newTotalFocus,
        totalBreakSeconds: newTotalBreak,
        totalPausedSeconds: newTotalPaused,
        phaseStartedAt: null,
        phaseEndsAt: null,
        pausedAt: null,
        pausedRemainingSeconds: null,
        completedAt: now,
      };
    }

    const isLongBreak = newCompletedSessions % plan.longBreakInterval === 0;
    const nextPhase: PomodoroPhase = isLongBreak ? "longBreak" : "shortBreak";
    const breakDuration = isLongBreak
      ? plan.longBreakDurationSeconds
      : plan.shortBreakDurationSeconds;

    if (plan.autoStartBreaks) {
      const phaseEndsAt = new Date(now.getTime() + breakDuration * 1000);
      return {
        status: nextPhase,
        currentPhase: nextPhase,
        completedSessions: newCompletedSessions,
        phaseStartedAt: now,
        phaseEndsAt,
        pausedAt: null,
        pausedRemainingSeconds: null,
        totalFocusSeconds: newTotalFocus,
        totalBreakSeconds: newTotalBreak,
        totalPausedSeconds: newTotalPaused,
      };
    } else {
      return {
        status: "paused",
        currentPhase: nextPhase,
        completedSessions: newCompletedSessions,
        pausedAt: now,
        pausedRemainingSeconds: breakDuration,
        phaseStartedAt: null,
        phaseEndsAt: null,
        totalFocusSeconds: newTotalFocus,
        totalBreakSeconds: newTotalBreak,
        totalPausedSeconds: newTotalPaused,
      };
    }
  } else {
    // Coming from break -> advance to next session's focus
    const nextSession = plan.completedSessions + 1;
    const focusDuration = plan.focusDurationSeconds;

    if (plan.autoStartFocus) {
      const phaseEndsAt = new Date(now.getTime() + focusDuration * 1000);
      return {
        status: "focus",
        currentPhase: "focus",
        currentSession: nextSession,
        phaseStartedAt: now,
        phaseEndsAt,
        pausedAt: null,
        pausedRemainingSeconds: null,
        totalFocusSeconds: newTotalFocus,
        totalBreakSeconds: newTotalBreak,
        totalPausedSeconds: newTotalPaused,
      };
    } else {
      return {
        status: "paused",
        currentPhase: "focus",
        currentSession: nextSession,
        pausedAt: now,
        pausedRemainingSeconds: focusDuration,
        phaseStartedAt: null,
        phaseEndsAt: null,
        totalFocusSeconds: newTotalFocus,
        totalBreakSeconds: newTotalBreak,
        totalPausedSeconds: newTotalPaused,
      };
    }
  }
}

export function calculateCancelTransition(
  plan: PomodoroPlanState,
  now: Date
): Partial<PomodoroPlanState> {
  let addFocus = 0;
  let addBreak = 0;
  let addPaused = 0;

  if (plan.status === "paused" && plan.pausedAt) {
    addPaused = Math.max(
      0,
      Math.floor((now.getTime() - plan.pausedAt.getTime()) / 1000)
    );
  } else if (plan.phaseStartedAt) {
    const elapsed = Math.max(
      0,
      Math.floor((now.getTime() - plan.phaseStartedAt.getTime()) / 1000)
    );
    if (plan.currentPhase === "focus") {
      addFocus = elapsed;
    } else {
      addBreak = elapsed;
    }
  }

  return {
    status: "cancelled",
    totalFocusSeconds: plan.totalFocusSeconds + addFocus,
    totalBreakSeconds: plan.totalBreakSeconds + addBreak,
    totalPausedSeconds: plan.totalPausedSeconds + addPaused,
    phaseStartedAt: null,
    phaseEndsAt: null,
    pausedAt: null,
    pausedRemainingSeconds: null,
    completedAt: now,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Database Persistence & Operations
// ─────────────────────────────────────────────────────────────────────────────

export async function ensurePomodoroTable(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS "pomodoro_plans" (
      "id" serial PRIMARY KEY NOT NULL,
      "user_id" integer NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "status" varchar(30) DEFAULT 'focus' NOT NULL,
      "current_phase" varchar(30) DEFAULT 'focus' NOT NULL,
      "current_session" integer DEFAULT 1 NOT NULL,
      "total_sessions" integer DEFAULT 4 NOT NULL,
      "focus_duration_seconds" integer DEFAULT 1500 NOT NULL,
      "short_break_duration_seconds" integer DEFAULT 300 NOT NULL,
      "long_break_duration_seconds" integer DEFAULT 900 NOT NULL,
      "long_break_interval" integer DEFAULT 4 NOT NULL,
      "auto_start_breaks" boolean DEFAULT false NOT NULL,
      "auto_start_focus" boolean DEFAULT false NOT NULL,
      "phase_started_at" timestamp with time zone,
      "phase_ends_at" timestamp with time zone,
      "paused_at" timestamp with time zone,
      "paused_remaining_seconds" integer,
      "total_focus_seconds" integer DEFAULT 0 NOT NULL,
      "total_break_seconds" integer DEFAULT 0 NOT NULL,
      "total_paused_seconds" integer DEFAULT 0 NOT NULL,
      "completed_sessions" integer DEFAULT 0 NOT NULL,
      "task_id" varchar(255),
      "task_title" varchar(255),
      "started_at" timestamp with time zone DEFAULT now() NOT NULL,
      "completed_at" timestamp with time zone,
      "updated_at" timestamp with time zone DEFAULT now() NOT NULL
    );
  `);
}

export async function getCurrentPlan(
  userId: number,
  now: Date = new Date()
): Promise<PomodoroPlan | null> {
  const activePlans = await db
    .select()
    .from(pomodoroPlans)
    .where(
      and(
        eq(pomodoroPlans.userId, userId),
        inArray(pomodoroPlans.status, ["focus", "shortBreak", "longBreak", "paused"])
      )
    )
    .orderBy(desc(pomodoroPlans.id))
    .limit(1);

  if (activePlans.length > 0) {
    return activePlans[0];
  }

  const recentPlans = await db
    .select()
    .from(pomodoroPlans)
    .where(eq(pomodoroPlans.userId, userId))
    .orderBy(desc(pomodoroPlans.id))
    .limit(1);

  if (recentPlans.length > 0) {
    const plan = recentPlans[0];
    if (plan.completedAt) {
      const diffMs = now.getTime() - plan.completedAt.getTime();
      if (diffMs < 30 * 60 * 1000) {
        return plan;
      }
    }
  }

  return null;
}

export async function startPlan(
  userId: number,
  params: PomodoroStartParams,
  now: Date = new Date()
): Promise<PomodoroPlan> {
  await cancelActivePlans(userId, now);

  const totalSessions = Math.max(1, params.totalSessions ?? 4);
  const focusDuration = Math.max(60, params.focusDurationSeconds ?? 1500);
  const shortBreakDuration = Math.max(30, params.shortBreakDurationSeconds ?? 300);
  const longBreakDuration = Math.max(60, params.longBreakDurationSeconds ?? 900);
  const longBreakInterval = Math.max(1, params.longBreakInterval ?? 4);

  const phaseEndsAt = new Date(now.getTime() + focusDuration * 1000);

  const [newPlan] = await db
    .insert(pomodoroPlans)
    .values({
      userId,
      status: "focus",
      currentPhase: "focus",
      currentSession: 1,
      totalSessions,
      focusDurationSeconds: focusDuration,
      shortBreakDurationSeconds: shortBreakDuration,
      longBreakDurationSeconds: longBreakDuration,
      longBreakInterval,
      autoStartBreaks: params.autoStartBreaks ?? false,
      autoStartFocus: params.autoStartFocus ?? false,
      phaseStartedAt: now,
      phaseEndsAt,
      pausedAt: null,
      pausedRemainingSeconds: null,
      totalFocusSeconds: 0,
      totalBreakSeconds: 0,
      totalPausedSeconds: 0,
      completedSessions: 0,
      taskId: params.taskId ?? null,
      taskTitle: params.taskTitle ?? null,
      startedAt: now,
      updatedAt: now,
    })
    .returning();

  return newPlan;
}

export async function pausePlan(
  userId: number,
  planId?: number,
  now: Date = new Date()
): Promise<PomodoroPlan> {
  const plan = await resolveActivePlan(userId, planId);
  if (!plan) {
    throw new Error("No active pomodoro plan to pause.");
  }

  const updates = calculatePauseTransition(toPlanState(plan), now);
  if (Object.keys(updates).length === 0) {
    return plan;
  }

  const [updated] = await db
    .update(pomodoroPlans)
    .set({
      ...updates,
      updatedAt: now,
    })
    .where(eq(pomodoroPlans.id, plan.id))
    .returning();

  return updated;
}

export async function resumePlan(
  userId: number,
  planId?: number,
  now: Date = new Date()
): Promise<PomodoroPlan> {
  const plan = await resolveActivePlan(userId, planId);
  if (!plan) {
    throw new Error("No active pomodoro plan to resume.");
  }

  const updates = calculateResumeTransition(toPlanState(plan), now);
  if (Object.keys(updates).length === 0) {
    return plan;
  }

  const [updated] = await db
    .update(pomodoroPlans)
    .set({
      ...updates,
      updatedAt: now,
    })
    .where(eq(pomodoroPlans.id, plan.id))
    .returning();

  return updated;
}

export async function nextPhase(
  userId: number,
  planId?: number,
  now: Date = new Date()
): Promise<PomodoroPlan> {
  const plan = await resolveActivePlan(userId, planId);
  if (!plan) {
    throw new Error("No active pomodoro plan found.");
  }

  const updates = calculateNextTransition(toPlanState(plan), now);

  const [updated] = await db
    .update(pomodoroPlans)
    .set({
      ...updates,
      updatedAt: now,
    })
    .where(eq(pomodoroPlans.id, plan.id))
    .returning();

  return updated;
}

export async function skipPhase(
  userId: number,
  planId?: number,
  now: Date = new Date()
): Promise<PomodoroPlan> {
  return nextPhase(userId, planId, now);
}

export async function cancelPlan(
  userId: number,
  planId?: number,
  now: Date = new Date()
): Promise<PomodoroPlan> {
  const plan = await resolveActivePlan(userId, planId);
  if (!plan) {
    throw new Error("No active pomodoro plan to cancel.");
  }

  const updates = calculateCancelTransition(toPlanState(plan), now);

  const [cancelled] = await db
    .update(pomodoroPlans)
    .set({
      ...updates,
      updatedAt: now,
    })
    .where(eq(pomodoroPlans.id, plan.id))
    .returning();

  return cancelled;
}

function toPlanState(plan: PomodoroPlan): PomodoroPlanState {
  return plan as unknown as PomodoroPlanState;
}

async function cancelActivePlans(userId: number, now: Date): Promise<void> {
  const activePlans = await db
    .select()
    .from(pomodoroPlans)
    .where(
      and(
        eq(pomodoroPlans.userId, userId),
        inArray(pomodoroPlans.status, ["focus", "shortBreak", "longBreak", "paused"])
      )
    );

  for (const plan of activePlans) {
    await db
      .update(pomodoroPlans)
      .set({
        status: "cancelled",
        completedAt: now,
        updatedAt: now,
      })
      .where(eq(pomodoroPlans.id, plan.id));
  }
}

async function resolveActivePlan(
  userId: number,
  planId?: number
): Promise<PomodoroPlan | null> {
  if (planId) {
    const [p] = await db
      .select()
      .from(pomodoroPlans)
      .where(
        and(eq(pomodoroPlans.id, planId), eq(pomodoroPlans.userId, userId))
      );
    return p ?? null;
  }
  return getCurrentPlan(userId);
}
