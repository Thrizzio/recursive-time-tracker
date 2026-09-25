export type PomodoroStatus =
  | "focus"
  | "shortBreak"
  | "longBreak"
  | "paused"
  | "completed"
  | "cancelled";

export type PomodoroPhase = "focus" | "shortBreak" | "longBreak";

export interface PomodoroPlan {
  id: number;
  userId: number;
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
  phaseStartedAt: string | null;
  phaseEndsAt: string | null;
  pausedAt: string | null;
  pausedRemainingSeconds: number | null;
  totalFocusSeconds: number;
  totalBreakSeconds: number;
  totalPausedSeconds: number;
  completedSessions: number;
  taskId: string | null;
  taskTitle: string | null;
  startedAt: string;
  completedAt: string | null;
  updatedAt: string;
}

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
