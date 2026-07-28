import { TimerState, StorageManager } from '../types/timer';
import { STORAGE_KEY, CURRENT_VERSION, validateTimerState } from './timer';

/**
 * Creates a storage manager for timer state persistence
 * Handles localStorage failures gracefully with session-only fallback
 */
export function createStorageManager(): StorageManager {
  // Test localStorage availability
  const isStorageAvailable = (() => {
    try {
      const test = '__timer_storage_test__';
      localStorage.setItem(test, test);
      localStorage.removeItem(test);
      return true;
    } catch {
      return false;
    }
  })();
  
  if (!isStorageAvailable) {
    console.warn('localStorage unavailable, timer will not persist across sessions');
    return createSessionOnlyManager();
  }
  
  return {
    save(state: TimerState): void {
      try {
        const stateWithVersion = {
          ...state,
          version: CURRENT_VERSION
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(stateWithVersion));
      } catch (error) {
        console.warn('Failed to save timer state:', error);
      }
    },
    
    load(): TimerState | null {
      try {
        const data = localStorage.getItem(STORAGE_KEY);
        if (!data) return null;
        
        const parsed = JSON.parse(data);
        
        // Handle version migrations if needed
        if (parsed.version !== CURRENT_VERSION) {
          console.log('Timer state version mismatch, resetting to default');
          this.clear();
          return null;
        }
        
        return validateTimerState(parsed) ? parsed : null;
      } catch (error) {
        console.warn('Failed to load timer state:', error);
        return null;
      }
    },
    
    clear(): void {
      try {
        localStorage.removeItem(STORAGE_KEY);
      } catch (error) {
        console.warn('Failed to clear timer state:', error);
      }
    },
    
    isAvailable(): boolean {
      return isStorageAvailable;
    }
  };
}

/**
 * Creates a session-only storage manager (fallback when localStorage unavailable)
 */
function createSessionOnlyManager(): StorageManager {
  let sessionState: TimerState | null = null;
  
  return {
    save(state: TimerState): void {
      sessionState = { ...state, version: CURRENT_VERSION };
    },
    
    load(): TimerState | null {
      return sessionState;
    },
    
    clear(): void {
      sessionState = null;
    },
    
    isAvailable(): boolean {
      return false;
    }
  };
}