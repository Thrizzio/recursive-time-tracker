import { useState, useEffect, useCallback, useMemo } from 'react';
import { PomodoroPlan, PomodoroStartParams } from '../types/pomodoro';
import * as pomodoroService from '../services/pomodoro';

export function usePomodoro() {
  const [plan, setPlan] = useState<PomodoroPlan | null>(null);
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

  const fetchCurrent = useCallback(() => {
    pomodoroService
      .getCurrentPlan()
      .then((current) => {
        setPlan(current);
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
        setPlan(custom.detail);
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
      setPlan(newPlan);
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
      setPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to pause pomodoro plan');
    }
  }, [plan]);

  const resume = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.resumePlan(plan.id);
      setPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to resume pomodoro plan');
    }
  }, [plan]);

  const next = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.nextPhase(plan.id);
      setPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to advance pomodoro phase');
    }
  }, [plan]);

  const skip = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.skipPhase(plan.id);
      setPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to skip pomodoro phase');
    }
  }, [plan]);

  const cancel = useCallback(async () => {
    if (!plan) return;
    try {
      const updated = await pomodoroService.cancelPlan(plan.id);
      setPlan(updated);
    } catch (err: any) {
      setError(err.message || 'Failed to cancel pomodoro plan');
    }
  }, [plan]);

  const updateFromWebSocket = useCallback((incomingPlan: PomodoroPlan) => {
    setPlan(incomingPlan);
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
