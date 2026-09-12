/**
 * Shared duration and allocation distribution logic for Chronolog.
 * Ensures consistent duration calculations and integer-remainder distribution
 * across session logging, time block retrieval, and daily summaries.
 */

export type AllocationInput = {
  activityId: number;
  percentage: number;
};

export type AllocationWithDuration<T extends { percentage: number }> = T & {
  durationSeconds: number;
};

/**
 * Calculates effective time boundaries and elapsed seconds for a time block,
 * optionally clamping to a window (e.g. [startOfDay, startOfNextDay)).
 */
export function calculateEffectiveBlock(
  blockStartTime: Date,
  blockEndTime: Date,
  windowStart?: Date,
  windowEnd?: Date
): {
  effectiveStart: Date;
  effectiveEnd: Date;
  elapsedSeconds: number;
} {
  const startMs = windowStart
    ? Math.max(blockStartTime.getTime(), windowStart.getTime())
    : blockStartTime.getTime();
  const endMs = windowEnd
    ? Math.min(blockEndTime.getTime(), windowEnd.getTime())
    : blockEndTime.getTime();

  const elapsedSeconds = Math.max(0, Math.round((endMs - startMs) / 1000));

  return {
    effectiveStart: new Date(startMs),
    effectiveEnd: new Date(endMs),
    elapsedSeconds,
  };
}

/**
 * Distributes elapsed seconds across allocations based on their percentage.
 * Uses Chronolog's canonical algorithm:
 * - Computes Math.floor((percentage / 100) * elapsedSeconds) for each allocation
 * - Gives the remaining seconds to the allocation with the largest percentage
 *   (ties: first one wins).
 * Guarantee: sum of durationSeconds equals elapsedSeconds (when elapsedSeconds >= 0).
 */
export function calculateAllocationDurations<T extends { percentage: number }>(
  elapsedSeconds: number,
  allocations: T[]
): Array<T & { durationSeconds: number }> {
  if (allocations.length === 0 || elapsedSeconds <= 0) {
    return allocations.map((a) => ({ ...a, durationSeconds: 0 }));
  }

  const results = allocations.map((a) => ({
    ...a,
    durationSeconds: Math.floor((a.percentage / 100) * elapsedSeconds),
  }));

  const sumFloor = results.reduce((s, d) => s + d.durationSeconds, 0);
  const remainder = elapsedSeconds - sumFloor;

  if (remainder > 0) {
    let largestIdx = 0;
    for (let i = 1; i < results.length; i++) {
      if (results[i].percentage > results[largestIdx].percentage) {
        largestIdx = i;
      }
    }
    results[largestIdx].durationSeconds += remainder;
  }

  return results;
}
