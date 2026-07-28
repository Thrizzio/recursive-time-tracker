/**
 * Timer state interface following the design specification
 * All timestamps are in milliseconds (Date.now() format)
 */
export interface TimerState {
  /** Total timer duration in milliseconds */
  duration: number;
  
  /** Current timer status */
  status: 'stopped' | 'running' | 'paused' | 'completed';
  
  /** Timestamp when timer was started (Date.now()) */
  startedAt: number | null;
  
  /** Timestamp when timer was paused (Date.now()) */
  pausedAt: number | null;
  
  /** Total time spent paused in milliseconds */
  totalPausedTime: number;
  
  /** Timestamp when timer completed (Date.now()) */
  completedAt: number | null;
  
  /** State format version for future migrations */
  version: number;
}

/**
 * Timer hook return interface
 */
export interface UseTimerReturn {
  /** Current timer state */
  state: TimerState;
  
  /** Current remaining time in milliseconds */
  remainingTime: number;
  
  /** Start the timer */
  start: () => void;
  
  /** Pause the running timer */
  pause: () => void;
  
  /** Resume a paused timer */
  resume: () => void;
  
  /** Reset timer to stopped state with original duration */
  reset: () => void;
  
  /** Set timer duration in milliseconds */
  setDuration: (milliseconds: number) => void;
}

/**
 * Storage manager interface for localStorage operations
 */
export interface StorageManager {
  save: (state: TimerState) => void;
  load: () => TimerState | null;
  clear: () => void;
  isAvailable: () => boolean;
}

/**
 * Timer preset duration in milliseconds
 */
export interface TimerPreset {
  label: string;
  duration: number;
}