import { TimerState } from '../../types/timer';

interface TimerControlsProps {
  state: TimerState;
  onStart: () => void;
  onPause: () => void;
  onResume: () => void;
  onReset: () => void;
}

/**
 * Timer control buttons that adapt based on current timer state
 */
export function TimerControls({ 
  state, 
  onStart, 
  onPause, 
  onResume, 
  onReset 
}: TimerControlsProps) {
  return (
    <div className="space-y-3">
      {/* Primary action button */}
      <div className="flex gap-2">
        {state.status === 'stopped' && (
          <button
            onClick={onStart}
            className="flex-1 rounded-lg bg-cyan-400 px-4 py-2.5 text-sm font-semibold text-zinc-950 hover:bg-cyan-300 transition-colors"
            aria-label="Start timer"
          >
            Start Timer
          </button>
        )}
        
        {state.status === 'running' && (
          <button
            onClick={onPause}
            className="flex-1 rounded-lg bg-orange-400 px-4 py-2.5 text-sm font-semibold text-zinc-950 hover:bg-orange-300 transition-colors"
            aria-label="Pause timer"
          >
            Pause
          </button>
        )}
        
        {state.status === 'paused' && (
          <button
            onClick={onResume}
            className="flex-1 rounded-lg bg-cyan-400 px-4 py-2.5 text-sm font-semibold text-zinc-950 hover:bg-cyan-300 transition-colors"
            aria-label="Resume timer"
          >
            Resume
          </button>
        )}
        
        {state.status === 'completed' && (
          <button
            onClick={onReset}
            className="flex-1 rounded-lg bg-cyan-400 px-4 py-2.5 text-sm font-semibold text-zinc-950 hover:bg-cyan-300 transition-colors"
            aria-label="Start new timer"
          >
            New Timer
          </button>
        )}
        
        {/* Reset button (available when timer is active but not completed) */}
        {(state.status === 'running' || state.status === 'paused') && (
          <button
            onClick={onReset}
            className="rounded-lg border border-zinc-600 px-3 py-2.5 text-sm font-medium text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 transition-colors"
            aria-label="Reset timer"
          >
            Reset
          </button>
        )}
      </div>
    </div>
  );
}