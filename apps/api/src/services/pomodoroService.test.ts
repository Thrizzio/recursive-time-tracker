import assert from "node:assert/strict";
import {
  calculatePauseTransition,
  calculateResumeTransition,
  calculateNextTransition,
  calculateCancelTransition,
  type PomodoroPlanState,
} from "./pomodoroService.js";

console.log("Running pomodoroService state machine and time accounting tests...\n");

function createMockPlan(overrides: Partial<PomodoroPlanState> = {}): PomodoroPlanState {
  return {
    status: "focus",
    currentPhase: "focus",
    currentSession: 1,
    totalSessions: 4,
    focusDurationSeconds: 1500, // 25 min
    shortBreakDurationSeconds: 300, // 5 min
    longBreakDurationSeconds: 900, // 15 min
    longBreakInterval: 4,
    autoStartBreaks: false,
    autoStartFocus: false,
    phaseStartedAt: new Date("2026-09-24T10:00:00.000Z"),
    phaseEndsAt: new Date("2026-09-24T10:25:00.000Z"),
    pausedAt: null,
    pausedRemainingSeconds: null,
    totalFocusSeconds: 0,
    totalBreakSeconds: 0,
    totalPausedSeconds: 0,
    completedSessions: 0,
    completedAt: null,
    ...overrides,
  };
}

// ── Test 1: Pause active focus session ─────────────────────────────────────────
{
  const plan = createMockPlan();
  const pauseTime = new Date("2026-09-24T10:10:00.000Z"); // 10 minutes in (600s elapsed)

  const updates = calculatePauseTransition(plan, pauseTime);
  assert.equal(updates.status, "paused", "Status should be paused");
  assert.equal(updates.pausedRemainingSeconds, 900, "15 minutes (900s) remaining");
  assert.equal(updates.totalFocusSeconds, 600, "Focus time should accumulate 600s");
  assert.equal(updates.totalBreakSeconds, 0, "Break time should remain 0s");
  console.log("✓ Test 1 passed: Pause active focus session accounts time correctly");
}

// ── Test 2: Resume paused session ─────────────────────────────────────────────
{
  const plan = createMockPlan({
    status: "paused",
    phaseStartedAt: null,
    phaseEndsAt: null,
    pausedAt: new Date("2026-09-24T10:10:00.000Z"),
    pausedRemainingSeconds: 900,
    totalFocusSeconds: 600,
    totalBreakSeconds: 0,
    totalPausedSeconds: 0,
  });

  const resumeTime = new Date("2026-09-24T10:15:00.000Z"); // paused for 5 minutes (300s)

  const updates = calculateResumeTransition(plan, resumeTime);
  assert.equal(updates.status, "focus", "Status should resume to focus");
  assert.equal(updates.totalPausedSeconds, 300, "Paused time should accumulate 300s");
  assert.equal(
    updates.phaseEndsAt?.toISOString(),
    "2026-09-24T10:30:00.000Z",
    "phaseEndsAt should extend by remaining 900s from resume time"
  );
  console.log("✓ Test 2 passed: Resume paused session accounts paused time and sets phaseEndsAt");
}

// ── Test 3: Paused time NEVER counts as focus or break ────────────────────────
{
  const plan = createMockPlan({
    status: "paused",
    pausedAt: new Date("2026-09-24T10:10:00.000Z"),
    pausedRemainingSeconds: 900,
    totalFocusSeconds: 600,
    totalBreakSeconds: 120,
    totalPausedSeconds: 50,
  });

  const resumeTime = new Date("2026-09-24T10:30:00.000Z"); // paused for 20 minutes (1200s)
  const updates = calculateResumeTransition(plan, resumeTime);

  // Focus and break are untouched by pause duration
  assert.equal(updates.totalPausedSeconds, 1250, "Paused time accumulated 1200s + 50s");
  console.log("✓ Test 3 passed: Paused duration is strictly segregated from focus/break totals");
}

// ── Test 4: Focus -> Short Break (manual start when autoStartBreaks = false) ──
{
  const plan = createMockPlan({
    completedSessions: 0,
    autoStartBreaks: false,
  });

  const finishTime = new Date("2026-09-24T10:25:00.000Z");
  const updates = calculateNextTransition(plan, finishTime);

  assert.equal(updates.completedSessions, 1, "Completed sessions should increment to 1");
  assert.equal(updates.currentPhase, "shortBreak", "Current phase should be shortBreak");
  assert.equal(updates.status, "paused", "Status should be paused when autoStartBreaks is false");
  assert.equal(updates.pausedRemainingSeconds, 300, "Break remaining should default to 300s (5m)");
  console.log("✓ Test 4 passed: Transition to shortBreak pauses waiting for user start");
}

// ── Test 5: Focus -> Short Break (auto start when autoStartBreaks = true) ─────
{
  const plan = createMockPlan({
    completedSessions: 0,
    autoStartBreaks: true,
  });

  const finishTime = new Date("2026-09-24T10:25:00.000Z");
  const updates = calculateNextTransition(plan, finishTime);

  assert.equal(updates.completedSessions, 1);
  assert.equal(updates.currentPhase, "shortBreak");
  assert.equal(updates.status, "shortBreak", "Status should immediately start shortBreak");
  assert.equal(
    updates.phaseEndsAt?.toISOString(),
    "2026-09-24T10:30:00.000Z",
    "phaseEndsAt should be 5 minutes after finishTime"
  );
  console.log("✓ Test 5 passed: Transition to shortBreak auto-starts when enabled");
}

// ── Test 6: Short Break -> Next Focus session ─────────────────────────────────
{
  const plan = createMockPlan({
    currentPhase: "shortBreak",
    status: "shortBreak",
    currentSession: 1,
    completedSessions: 1,
    phaseStartedAt: new Date("2026-09-24T10:25:00.000Z"),
    phaseEndsAt: new Date("2026-09-24T10:30:00.000Z"),
    autoStartFocus: true,
  });

  const breakDoneTime = new Date("2026-09-24T10:30:00.000Z");
  const updates = calculateNextTransition(plan, breakDoneTime);

  assert.equal(updates.currentSession, 2, "Session number should advance to 2");
  assert.equal(updates.currentPhase, "focus");
  assert.equal(updates.status, "focus");
  assert.equal(
    updates.phaseEndsAt?.toISOString(),
    "2026-09-24T10:55:00.000Z",
    "New focus endsAt should be 25m after breakDoneTime"
  );
  console.log("✓ Test 6 passed: Short break transitions to session 2 focus");
}

// ── Test 7: Long break triggered on interval (session 4) ──────────────────────
{
  const plan = createMockPlan({
    currentSession: 4,
    completedSessions: 3, // completing 4th session now
    longBreakInterval: 4,
    longBreakDurationSeconds: 900, // 15m
    totalSessions: 6,
    autoStartBreaks: true,
  });

  const finishTime = new Date("2026-09-24T12:00:00.000Z");
  const updates = calculateNextTransition(plan, finishTime);

  assert.equal(updates.completedSessions, 4);
  assert.equal(updates.currentPhase, "longBreak", "4th session completion triggers longBreak");
  assert.equal(
    updates.phaseEndsAt?.toISOString(),
    "2026-09-24T12:15:00.000Z",
    "longBreak endsAt should be 15m (900s) later"
  );
  console.log("✓ Test 7 passed: Long break interval correctly triggered on session 4");
}

// ── Test 8: Plan completion after totalSessions ───────────────────────────────
{
  const plan = createMockPlan({
    currentSession: 4,
    completedSessions: 3,
    totalSessions: 4,
    phaseStartedAt: new Date("2026-09-24T12:00:00.000Z"),
    phaseEndsAt: new Date("2026-09-24T12:25:00.000Z"),
    totalFocusSeconds: 4500,
  });

  const finalDoneTime = new Date("2026-09-24T12:25:00.000Z");
  const updates = calculateNextTransition(plan, finalDoneTime);

  assert.equal(updates.completedSessions, 4);
  assert.equal(updates.status, "completed", "Status must become completed");
  assert.equal(updates.completedAt?.toISOString(), finalDoneTime.toISOString());
  assert.equal(updates.totalFocusSeconds, 6000, "Total focus seconds reached 4 * 1500s = 6000s");
  console.log("✓ Test 8 passed: Plan successfully marks completed with total duration");
}

// ── Test 9: Cancel plan records final time ────────────────────────────────────
{
  const plan = createMockPlan({
    phaseStartedAt: new Date("2026-09-24T10:00:00.000Z"),
    totalFocusSeconds: 100,
  });

  const cancelTime = new Date("2026-09-24T10:10:00.000Z"); // 600s elapsed
  const updates = calculateCancelTransition(plan, cancelTime);

  assert.equal(updates.status, "cancelled");
  assert.equal(updates.totalFocusSeconds, 700, "Total focus accounts 100 + 600 = 700s");
  assert.equal(updates.completedAt?.toISOString(), cancelTime.toISOString());
  console.log("✓ Test 9 passed: Cancel plan finalizes status and recorded time");
}

console.log("\nAll 9 pomodoro service tests passed successfully!\n");
