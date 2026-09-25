# ADR 0001: Pomodoro Timestamp-Derived State Transitions

## Status
Accepted

## Context
When a Pomodoro phase countdown reaches `00:00`, the timer on both web and mobile could stall displaying `00:00` (e.g. `FOCUS PHASE — Session 1 of 4`) rather than cleanly transitioning into the next phase (Short Break, Long Break, next Focus session, or Pomodoro Complete).

Previously, state transitions relied on manual user interaction or expected continuous 1-second interval execution. If an app was backgrounded, device was locked, tabs throttled, or client reconnected after a phase's scheduled end time (`phaseEndsAt`), no transition occurred because neither backend queries (`getCurrentPlan`) nor client models derived the phase from timestamps.

## Decision
1. Implement a pure sequential state transition advancement function (`advancePlanToTime` on API and `advanceToTime` on Mobile) that advances any unpaused plan past expired `phaseEndsAt` boundaries up to `now`.
2. When a focus session finishes:
   - If sessions remain: increments `completedSessions`, selects Short Break or Long Break (if `completedSessions % longBreakInterval === 0`), advances `currentSession = completedSessions + 1`, and starts the break countdown.
   - If final session finishes: transitions to `status: "completed"` with `completedAt` set.
3. When a break finishes:
   - Advances to the next focus session (`currentSession = completedSessions + 1`), sets `status: "focus"`, and resets countdown to `focusDurationSeconds`.
4. Derive current phase and countdown from timestamps both on backend reads (`getCurrentPlan`, `resolveActivePlan`) and on frontend tickers/mounts, rather than relying strictly on client-side 1-second ticks.
5. In the UI headers, clearly display "Next: Session X of Y" during break phases, and "Session X of Y" during focus phases.

## Alternatives Considered
- **Client-driven manual tick trigger**: Trigger an HTTP POST `/pomodoro/next` whenever a 1-second ticker hits 0. Rejected because throttled background execution, network drops, or tab sleeps miss the boundary and leave the timer stalled at `00:00`.
- **Server cron/background worker**: Running a background worker on the server checking elapsed phases every second. Rejected as unnecessary overhead and complex distributed state management; timestamp derivation on read/tick is deterministic, stateless, and always correct.

## Consequences
- Timers never stall at `00:00`.
- Reopening the app or reconnecting after phase expiry instantly displays the accurate phase, session number, and remaining countdown.
- Paused time and pause/resume logic remain strictly segregated and preserved.
- No changes to database schema or external system boundaries.
