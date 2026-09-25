import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import { PomodoroPlan, PomodoroStartParams, PomodoroPhase } from '../types/pomodoro';
import * as pomodoroService from '../services/pomodoro';
import { showNotification, playNotificationSound } from '../utils/notifications';
import { getNotificationPrefs } from '../utils/notificationPrefs';

// Pure client-side advancement matching server state machine
function advancePlan(plan: PomodoroPlan, nowMs: number): { plan: PomodoroPlan; changed: boolean } {
  if (plan.status === 'completed' || plan.status === 'cancelled' || plan.status === 'paused') {
    return { plan, changed: false };
  }
  if (!plan.phaseEndsAt || nowMs < new Date(plan.phaseEndsAt).getTime()) {
    return { plan, changed: false };
  }

  let current = { ...plan };
  let changed = false;

  while (
    current.status !== 'completed' &&
    current.status !== 'cancelled' &&
    current.status !== 'paused' &&
    current.phaseEndsAt &&
    nowMs >= new Date(current.phaseEndsAt).getTime()
  ) {
    changed = true;
    const boundary = new Date(current.phaseEndsAt).getTime();
    const phaseStarted = current.phaseStartedAt ? new Date(current.phaseStartedAt).getTime() : boundary;
    const elapsed = Math.max(0, Math.floor((boundary - phaseStarted) / 1000));

    const addFocus = current.currentPhase === 'focus' ? elapsed : 0;
    const addBreak = current.currentPhase !== 'focus' ? elapsed : 0;

    const newTotalFocus = current.totalFocusSeconds + addFocus;
    const newTotalBreak = current.totalBreakSeconds + addBreak;

    if (current.currentPhase === 'focus') {
      const newCompleted = current.completedSessions + 1;
      if (newCompleted >= current.totalSessions) {
        current = {
          ...current,
          status: 'completed',
          currentSession: current.totalSessions,
          completedSessions: newCompleted,
          totalFocusSeconds: newTotalFocus,
          totalBreakSeconds: newTotalBreak,
          phaseStartedAt: null,
          phaseEndsAt: null,
          completedAt: new Date(boundary).toISOString(),
        };
        break;
      }

      const isLong = newCompleted % current.longBreakInterval === 0;
      const nextPhase: PomodoroPhase = isLong ? 'longBreak' : 'shortBreak';
      const breakDuration = isLong ? current.longBreakDurationSeconds : current.shortBreakDurationSeconds;

      if (current.autoStartBreaks !== false) {
        const nextEnd = boundary + breakDuration * 1000;
        current = {
          ...current,
          status: nextPhase,
          currentPhase: nextPhase,
          currentSession: newCompleted + 1,
          completedSessions: newCompleted,
          phaseStartedAt: new Date(boundary).toISOString(),
          phaseEndsAt: new Date(nextEnd).toISOString(),
          totalFocusSeconds: newTotalFocus,
          totalBreakSeconds: newTotalBreak,
        };
      } else {
        current = {
          ...current,
          status: 'paused',
          currentPhase: nextPhase,
          currentSession: newCompleted + 1,
          completedSessions: newCompleted,
          pausedAt: new Date(boundary).toISOString(),
          pausedRemainingSeconds: breakDuration,
          phaseStartedAt: null,
          phaseEndsAt: null,
          totalFocusSeconds: newTotalFocus,
          totalBreakSeconds: newTotalBreak,
        };
        break;
      }
    } else {
      // Break -> Focus
      const nextSession = current.completedSessions + 1;
      const focusDuration = current.focusDurationSeconds;

      if (current.autoStartFocus !== false) {
        const nextEnd = boundary + focusDuration * 1000;
        current = {
          ...current,
          status: 'focus',
          currentPhase: 'focus',
          currentSession: nextSession,
          phaseStartedAt: new Date(boundary).toISOString(),
          phaseEndsAt: new Date(nextEnd).toISOString(),
          totalFocusSeconds: newTotalFocus,
          totalBreakSeconds: newTotalBreak,
        };
      } else {
        current = {
          ...current,
          status: 'paused',
          currentPhase: 'focus',
          currentSession: nextSession,
          pausedAt: new Date(boundary).toISOString(),
          pausedRemainingSeconds: focusDuration,
          phaseStartedAt: null,
          phaseEndsAt: null,
          totalFocusSeconds: newTotalFocus,
          totalBreakSeconds: newTotalBreak,
        };
        break;
      }
    }
  }

  return { plan: current, changed };
}

export function usePomodoro() {
  const [rawPlan, setRawPlan] = useState<PomodoroPlan | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState<number>(Date.now());

  // 1-second local ticker to keep countdown and stats smooth without network ticks
  useEffect(() => {
    const timer = setInterval(() => {
      setNow(Date.now());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Actively advance plan from timestamps on every tick/eval
  const plan = useMemo(() => {
    if (!rawPlan) return null;
    return advancePlan(rawPlan, now).plan;
  }, [rawPlan, now]);

  // Decoupled notification side effect on Pomodoro phase transitions
  const lastPhaseKeyRef = useRef<string | null>(null);

  useEffect(() => {
    if (!plan) {
      lastPhaseKeyRef.current = null;
      return;
    }

    const currentKey = `${plan.id}:${plan.status}:${plan.currentPhase}:${plan.currentSession}:${plan.completedSessions}`;

    // On initial mount or if plan just loaded, record key without notifying
    if (lastPhaseKeyRef.current === null) {
      lastPhaseKeyRef.current = currentKey;
      return;
    }

    if (lastPhaseKeyRef.current !== currentKey) {
      lastPhaseKeyRef.current = currentKey;

      // Only notify when enabled in settings
      if (getNotificationPrefs().timerNotificationsEnabled) {
        try {
          if (plan.status === 'completed') {
            showNotification(
              'Pomodoro Complete!',
              `Great job! You finished all ${plan.totalSessions} focus sessions.`
            );
            playNotificationSound();
          } else if (plan.status === 'focus') {
            showNotification(
              `Focus Session ${plan.currentSession} Started`,
              `Time to focus! Session ${plan.currentSession} of ${plan.totalSessions} is underway.`
            );
            playNotificationSound();
          } else if (plan.currentPhase === 'longBreak') {
            showNotification(
              'Long Break Started',
              `Enjoy your long break! Session ${plan.currentSession} of ${plan.totalSessions} begins after this.`
            );
            playNotificationSound();
          } else if (plan.currentPhase === 'shortBreak') {
            showNotification(
              'Short Break Started',
              `Take a break! Session ${plan.currentSession} of ${plan.totalSessions} begins after this.`
            );
            playNotificationSound();
          }
        } catch {
          // Notifications are strictly independent: never throw or disrupt Pomodoro state
        }
      }
    }
  }, [plan]);

  const fetchCurrent = useCallback(() => {
    pomodoroService
      .getCurrentPlan()
      .then((current) => {
        setRawPlan(current);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message || 'Failed to load pomodoro plan');
        setLoading(false);
      });
  }, []);

  // Fetch current plan on mount
  useEffect(() => {
    fetchCurrent();

    const handleUpdate = (e: Event) => {
      const custom = e as CustomEvent<PomodoroPlan>;
      if (custom.detail !== undefined) {
        setRawPlan(custom.detail);
      }
    };

    const handleReconnect = () => {
      fetchCurrent();
    };

    window.addEventListener('pomodoro:updated', handleUpdate);
    window.addEventListener('pomodoro:reconnect', handleReconnect);

    return () => {
      window.removeEventListener('pomodoro:updated', handleUpdate);
      window.removeEventListener('pomodoro:reconnect', handleReconnect);
    };
  }, [fetchCurrent]);

  // Sync with backend if client advanced past boundary
  useEffect(() => {
    if (!rawPlan || rawPlan.status === 'completed' || rawPlan.status === 'cancelled' || rawPlan.status === 'paused') {
      return;
    }
    if (rawPlan.phaseEndsAt && now >= new Date(rawPlan.phaseEndsAt).getTime()) {
      const { plan: advanced, changed } = advancePlan(rawPlan, now);
      if (changed) {
        setRawPlan(advanced);
        pomodoroService.getCurrentPlan().then((remote) => {
          if (remote) setRawPlan(remote);
        }).catch(() => {});
      }
    }
  }, [rawPlan, now]);

  // Timestamp-derived remaining countdown
  const remainingSeconds = useMemo(() => {
    if (!plan) return 0;
    if (plan.status === 'completed' || plan.status === 'cancelled') return 0;
    if (plan.status === 'paused') {
      return plan.pausedRemainingSeconds ?? 0;
    }
    if (plan.phaseEndsAt) {
      const diffMs = new Date(plan.phaseEndsAt).getTime() - now;
      return Math.max(0, Math.ceil(diffMs / 1000));
    }
    return 0;
  }, [plan, now]);

  // Derived distinct time totals: Focus, Break, and Paused (strictly segregated)
  const liveStats = useMemo(() => {
    if (!plan) {
      return { totalFocus: 0, totalBreak: 0, totalPaused: 0 };
    }

    let extraFocus = 0;
    let extraBreak = 0;
    let extraPaused = 0;

    if (plan.status === 'focus' && plan.phaseStartedAt) {
      extraFocus = Math.max(0, Math.floor((now - new Date(plan.phaseStartedAt).getTime()) / 1000));
    } else if ((plan.status === 'shortBreak' || plan.status === 'longBreak') && plan.phaseStartedAt) {
      extraBreak = Math.max(0, Math.floor((now - new Date(plan.phaseStartedAt).getTime()) / 1000));
    } else if (plan.status === 'paused' && plan.pausedAt) {
      extraPaused = Math.max(0, Math.floor((now - new Date(plan.pausedAt).getTime()) / 1000));
    }

    return {
      totalFocus: plan.totalFocusSeconds + extraFocus,
      totalBreak: plan.totalBreakSeconds + extraBreak,
      totalPaused: plan.totalPausedSeconds + extraPaused,
    };
  }, [plan, now]);

  const start = useCallback(async (params: PomodoroStartParams) => {
    setError(null);
    try {
      const newPlan = await pomodoroService.startPlan(params);
      setRawPlan(newPlan);
      return newPlan;
    } catch (err: any) {
      setError(err.message || 'Failed to start pomodoro plan');
      throw err;
    }
  }, []);

  const pause = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.pausePlan(plan.id);
      setRawPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to pause pomodoro plan');
    }
  }, [plan]);

  const resume = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.resumePlan(plan.id);
      setRawPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to resume pomodoro plan');
    }
  }, [plan]);

  const next = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.nextPhase(plan.id);
      setRawPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to advance pomodoro phase');
    }
  }, [plan]);

  const skip = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.skipPhase(plan.id);
      setRawPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to skip pomodoro phase');
    }
  }, [plan]);

  const cancel = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.cancelPlan(plan.id);
      setRawPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to cancel pomodoro plan');
    }
  }, [plan]);

  const updateFromWebSocket = useCallback((incomingPlan: PomodoroPlan) => {
    setRawPlan(incomingPlan);
  }, []);

  return {
    plan,
    loading,
    error,
    remainingSeconds,
    liveStats,
    start,
    pause,
    resume,
    next,
    skip,
    cancel,
    updateFromWebSocket,
  };
}
