import { TimerState } from '../types/timer';

/** Current state format version */
export const CURRENT_VERSION = 1;

/** localStorage key for timer state */
export const STORAGE_KEY = 'chronolog-timer-state';

/** Default timer state (25 minutes) */
export const DEFAULT_TIMER_STATE: TimerState = {
  duration: 25 * 60 * 1000, // 25 minutes
  status: 'stopped',
  startedAt: null,
  pausedAt: null,
  totalPausedTime: 0,
  completedAt: null,
  version: CURRENT_VERSION
};

/** Timer presets */
export const TIMER_PRESETS = [
  { label: '25 min', duration: 25 * 60 * 1000 },
  { label: '50 min', duration: 50 * 60 * 1000 }
];

/**
 * Validates timer state object structure and types
 */
export function validateTimerState(obj: any): obj is TimerState {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof obj.duration === 'number' &&
    ['stopped', 'running', 'paused', 'completed'].includes(obj.status) &&
    (obj.startedAt === null || typeof obj.startedAt === 'number') &&
    (obj.pausedAt === null || typeof obj.pausedAt === 'number') &&
    (obj.completedAt === null || typeof obj.completedAt === 'number') &&
    typeof obj.totalPausedTime === 'number' &&
    typeof obj.version === 'number'
  );
}

/**
 * Validates timer duration is within acceptable range (1-180 minutes)
 */
export function validateDuration(duration: number): boolean {
  return (
    Number.isInteger(duration) &&
    duration >= 60000 &&      // Minimum 1 minute
    duration <= 10800000      // Maximum 180 minutes (3 hours)
  );
}

/**
 * Calculate remaining time based on current timestamp and timer state
 * This is the core accuracy mechanism using timestamps as source of truth
 */
export function calculateRemainingTime(state: TimerState): number {
  if (state.status === 'stopped') {
    return state.duration;
  }
  
  if (state.status === 'completed') {
    return 0;
  }
  
  const now = Date.now();
  
  if (state.status === 'running') {
    if (!state.startedAt) return state.duration;
    
    const elapsed = now - state.startedAt - state.totalPausedTime;
    return Math.max(0, state.duration - elapsed);
  }
  
  if (state.status === 'paused') {
    if (!state.startedAt || !state.pausedAt) return state.duration;
    
    const elapsed = state.pausedAt - state.startedAt - state.totalPausedTime;
    return Math.max(0, state.duration - elapsed);
  }
  
  return state.duration;
}

/**
 * Check if timer has expired (reached zero)
 */
export function isTimerExpired(state: TimerState): boolean {
  return calculateRemainingTime(state) === 0 && state.status === 'running';
}

/**
 * Format milliseconds as MM:SS or HH:MM:SS
 */
export function formatTime(milliseconds: number): string {
  const totalSeconds = Math.ceil(milliseconds / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  
  if (hours > 0) {
    return [hours, minutes, seconds]
      .map(val => val.toString().padStart(2, '0'))
      .join(':');
  }
  
  return [minutes, seconds]
    .map(val => val.toString().padStart(2, '0'))
    .join(':');
}

/**
 * Convert minutes to milliseconds
 */
export function minutesToMilliseconds(minutes: number): number {
  return minutes * 60 * 1000;
}

/**
 * Convert milliseconds to minutes
 */
export function millisecondsToMinutes(milliseconds: number): number {
  return Math.round(milliseconds / (60 * 1000));
}