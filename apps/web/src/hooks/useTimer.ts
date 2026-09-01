import { useState, useEffect, useCallback, useRef } from 'react';
import { showNotification, playNotificationSound } from '../utils/notifications';
import { getNotificationPrefs } from '../utils/notificationPrefs';
import { TimerState, UseTimerReturn } from '../types/timer';
import {
  DEFAULT_TIMER_STATE,
  calculateRemainingTime,
  validateDuration,
  validateTimerState,
  STORAGE_KEY
} from '../utils/timer';
import { createStorageManager } from '../utils/storage';

/**
 * Timer hook with localStorage persistence and cross-tab synchronization
 */
export function useTimer(): UseTimerReturn {
  const [state, setState] = useState<TimerState>(() => {
    const storageManager = createStorageManager();
    return storageManager.load() || DEFAULT_TIMER_STATE;
  });
  
  const [remainingTime, setRemainingTime] = useState(() => calculateRemainingTime(state));
  const storageManagerRef = useRef(createStorageManager());
  const updateLoopRef = useRef<number | null>(null);
  
  // Save state to localStorage on meaningful changes
  const saveState = useCallback((newState: TimerState) => {
    storageManagerRef.current.save(newState);
  }, []);
  
  // Update remaining time calculation
  const updateRemainingTime = useCallback(() => {
    const currentState = state;
    const remaining = calculateRemainingTime(currentState);
    setRemainingTime(remaining);
    
    // Check for completion
    if (remaining === 0 && currentState.status === 'running') {
      const now = Date.now();
      const completedState = {
        ...currentState,
        status: 'completed' as const,
        completedAt: now
      };
      setState(completedState);
      saveState(completedState);

      // Notify once — the running→completed transition is a one-way gate,
      // so this block can only execute once per timer run.
      if (getNotificationPrefs().timerNotificationsEnabled) {
        showNotification('Timer finished', 'Time to take a short break.');
        playNotificationSound();
      }
    }
  }, [state, saveState]);
  
  // Start update loop for running timers
  const startUpdateLoop = useCallback(() => {
    if (updateLoopRef.current) return;
    
    updateLoopRef.current = window.setInterval(() => {
      updateRemainingTime();
    }, 1000);
  }, [updateRemainingTime]);
  
  // Stop update loop
  const stopUpdateLoop = useCallback(() => {
    if (updateLoopRef.current) {
      clearInterval(updateLoopRef.current);
      updateLoopRef.current = null;
    }
  }, []);
  
  // Cross-tab synchronization
  useEffect(() => {
    function handleStorageChange(event: StorageEvent) {
      if (event.key !== STORAGE_KEY || !event.newValue) return;
      
      try {
        const newState = JSON.parse(event.newValue);
        if (validateTimerState(newState)) {
          setState(newState);
        }
      } catch (error) {
        console.warn('Failed to sync timer state:', error);
      }
    }
    
    window.addEventListener('storage', handleStorageChange);
    return () => window.removeEventListener('storage', handleStorageChange);
  }, []);
  
  // Manage update loop based on timer state
  useEffect(() => {
    if (state.status === 'running') {
      startUpdateLoop();
    } else {
      stopUpdateLoop();
    }
    
    return () => stopUpdateLoop();
  }, [state.status, startUpdateLoop, stopUpdateLoop]);
  
  // Update remaining time when state changes
  useEffect(() => {
    setRemainingTime(calculateRemainingTime(state));
  }, [state]);
  
  // Cleanup on unmount
  useEffect(() => {
    return () => stopUpdateLoop();
  }, [stopUpdateLoop]);
  
  // Timer actions
  const start = useCallback(() => {
    const now = Date.now();
    setState(prevState => {
      const newState = {
        ...prevState,
        status: 'running' as const,
        startedAt: now,
        pausedAt: null,
        completedAt: null
      };
      saveState(newState);
      return newState;
    });
  }, [saveState]);
  
  const pause = useCallback(() => {
    const now = Date.now();
    setState(prevState => {
      if (prevState.status !== 'running') return prevState;
      
      const newState = {
        ...prevState,
        status: 'paused' as const,
        pausedAt: now
      };
      saveState(newState);
      return newState;
    });
  }, [saveState]);
  
  const resume = useCallback(() => {
    const now = Date.now();
    setState(prevState => {
      if (prevState.status !== 'paused' || !prevState.pausedAt) return prevState;
      
      const pausedDuration = now - prevState.pausedAt;
      const newState = {
        ...prevState,
        status: 'running' as const,
        pausedAt: null,
        totalPausedTime: prevState.totalPausedTime + pausedDuration
      };
      saveState(newState);
      return newState;
    });
  }, [saveState]);
  
  const reset = useCallback(() => {
    setState(prevState => {
      const newState = {
        ...prevState,
        status: 'stopped' as const,
        startedAt: null,
        pausedAt: null,
        totalPausedTime: 0,
        completedAt: null
      };
      saveState(newState);
      return newState;
    });
  }, [saveState]);
  
  const setDuration = useCallback((milliseconds: number) => {
    if (!validateDuration(milliseconds)) return;
    
    setState(prevState => {
      const newState = {
        ...prevState,
        duration: milliseconds,
        status: 'stopped' as const,
        startedAt: null,
        pausedAt: null,
        totalPausedTime: 0,
        completedAt: null
      };
      saveState(newState);
      return newState;
    });
  }, [saveState]);
  
  return {
    state,
    remainingTime,
    start,
    pause,
    resume,
    reset,
    setDuration
  };
}