import assert from "node:assert/strict";
import {
  calculateEffectiveBlock,
  calculateAllocationDurations,
} from "./timeCalculations.js";

console.log("Running timeCalculations verification tests...\n");

// Case 1: Block entirely within window
{
  const start = new Date("2026-09-12T10:00:00.000Z");
  const end = new Date("2026-09-12T11:00:00.000Z");
  const windowStart = new Date("2026-09-12T00:00:00.000Z");
  const windowEnd = new Date("2026-09-13T00:00:00.000Z");

  const result = calculateEffectiveBlock(start, end, windowStart, windowEnd);
  assert.equal(result.elapsedSeconds, 3600, "1-hour block within day should equal 3600s");
  assert.equal(result.effectiveStart.toISOString(), "2026-09-12T10:00:00.000Z");
  assert.equal(result.effectiveEnd.toISOString(), "2026-09-12T11:00:00.000Z");
  console.log("✓ Case 1 passed: Block entirely within window");
}

// Case 2: Cross-midnight block (yesterday 23:30 to today 00:30) evaluated for TODAY
{
  const start = new Date("2026-09-11T23:30:00.000Z");
  const end = new Date("2026-09-12T00:30:00.000Z");
  const todayStart = new Date("2026-09-12T00:00:00.000Z");
  const todayEnd = new Date("2026-09-13T00:00:00.000Z");

  const todayResult = calculateEffectiveBlock(start, end, todayStart, todayEnd);
  assert.equal(todayResult.elapsedSeconds, 1800, "Midnight crossing block should attribute 1800s (30m) to today");
  assert.equal(todayResult.effectiveStart.toISOString(), "2026-09-12T00:00:00.000Z");
  assert.equal(todayResult.effectiveEnd.toISOString(), "2026-09-12T00:30:00.000Z");

  // Also verify for YESTERDAY
  const yesterdayStart = new Date("2026-09-11T00:00:00.000Z");
  const yesterdayEnd = new Date("2026-09-12T00:00:00.000Z");
  const yesterdayResult = calculateEffectiveBlock(start, end, yesterdayStart, yesterdayEnd);
  assert.equal(yesterdayResult.elapsedSeconds, 1800, "Midnight crossing block should attribute 1800s (30m) to yesterday");
  assert.equal(yesterdayResult.effectiveStart.toISOString(), "2026-09-11T23:30:00.000Z");
  assert.equal(yesterdayResult.effectiveEnd.toISOString(), "2026-09-12T00:00:00.000Z");
  console.log("✓ Case 2 passed: Cross-midnight block cleanly split 30m / 30m at midnight boundary");
}

// Case 3: Block outside window (yesterday's block queried for today)
{
  const start = new Date("2026-09-11T14:00:00.000Z");
  const end = new Date("2026-09-11T15:30:00.000Z");
  const todayStart = new Date("2026-09-12T00:00:00.000Z");
  const todayEnd = new Date("2026-09-13T00:00:00.000Z");

  const result = calculateEffectiveBlock(start, end, todayStart, todayEnd);
  assert.equal(result.elapsedSeconds, 0, "Yesterday's block should have 0s in today's window");
  console.log("✓ Case 3 passed: Yesterday's block has 0s overlap with today");
}

// Case 4: Allocation distribution with exact sums and remainder handling
{
  const elapsedSeconds = 100;
  const allocations = [
    { activityId: 1, percentage: 33 },
    { activityId: 2, percentage: 33 },
    { activityId: 3, percentage: 34 },
  ];

  const distributed = calculateAllocationDurations(elapsedSeconds, allocations);
  const sum = distributed.reduce((s, a) => s + a.durationSeconds, 0);
  assert.equal(sum, elapsedSeconds, "Allocations sum must exactly equal elapsedSeconds");
  assert.equal(distributed[0].durationSeconds, 33);
  assert.equal(distributed[1].durationSeconds, 33);
  assert.equal(distributed[2].durationSeconds, 34);
  console.log("✓ Case 4 passed: Allocation distribution sums exactly to total");
}

// Case 5: Remainder assigned to largest allocation
{
  // 99 seconds with 60% and 40%
  // 60% of 99 = 59.4 -> floor 59
  // 40% of 99 = 39.6 -> floor 39
  // sumFloor = 98, remainder = 1 -> added to 60% allocation (largest) -> 60
  const elapsedSeconds = 99;
  const allocations = [
    { activityId: 1, percentage: 60 },
    { activityId: 2, percentage: 40 },
  ];

  const distributed = calculateAllocationDurations(elapsedSeconds, allocations);
  assert.equal(distributed[0].durationSeconds, 60, "Largest allocation receives rounding remainder");
  assert.equal(distributed[1].durationSeconds, 39);
  assert.equal(distributed[0].durationSeconds + distributed[1].durationSeconds, 99);
  console.log("✓ Case 5 passed: Rounding remainder correctly assigned to largest allocation");
}

console.log("\nAll timeCalculations tests passed successfully!");
