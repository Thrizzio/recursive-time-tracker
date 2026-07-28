import { useState } from 'react';
import { useTimer } from '../../hooks/useTimer';
import { TimerDisplay } from './TimerDisplay';
import { TimerControls } from './TimerControls';
import { TimerSettings } from './TimerSettings';
import { formatTime } from '../../utils/timer';

/**
 * Main timer panel component with responsive design
 * - Mobile: Collapsible section
 * - Desktop: Always visible sidebar panel
 */
export function TimerPanel() {
  const [isExpanded, setIsExpanded] = useState(false);
  const { state, remainingTime, start, pause, resume, reset, setDuration } = useTimer();
  
  const canChangeDuration = state.status === 'stopped';
  
  return (
    <>
      {/* Mobile: Collapsible header */}
      <div className="lg:hidden">
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="w-full rounded-lg border border-zinc-700 bg-zinc-900 px-4 py-3 text-left hover:bg-zinc-800/60 transition-colors"
          aria-expanded={isExpanded}
          aria-label="Toggle timer panel"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-sm font-medium text-zinc-200">Timer</div>
              <div className="text-xs font-mono text-zinc-400">
                {formatTime(remainingTime)}
              </div>
              <div className={`text-xs px-2 py-0.5 rounded-full ${
                state.status === 'completed' 
                  ? 'bg-emerald-900 text-emerald-300' 
                  : state.status === 'running' 
                    ? 'bg-cyan-900 text-cyan-300' 
                    : state.status === 'paused'
                      ? 'bg-orange-900 text-orange-300'
                      : 'bg-zinc-800 text-zinc-400'
              }`}>
                {state.status === 'completed' ? 'Done' : 
                 state.status === 'running' ? 'Running' :
                 state.status === 'paused' ? 'Paused' : 'Ready'}
              </div>
            </div>
            <svg
              className={`h-4 w-4 text-zinc-400 transition-transform ${isExpanded ? 'rotate-180' : ''}`}
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <polyline points="6 9 12 15 18 9" />
            </svg>
          </div>
        </button>
        
        {isExpanded && (
          <div className="mt-3 rounded-lg border border-zinc-700 bg-zinc-900 p-4 space-y-4">
            <TimerDisplay remainingTime={remainingTime} status={state.status} />
            <TimerControls 
              state={state}
              onStart={start}
              onPause={pause}
              onResume={resume}
              onReset={reset}
            />
            <TimerSettings
              duration={state.duration}
              onDurationChange={setDuration}
              disabled={!canChangeDuration}
            />
          </div>
        )}
      </div>
      
      {/* Desktop: Always visible panel */}
      <div className="hidden lg:block rounded-lg border border-zinc-700 bg-zinc-900 p-4 space-y-4">
        <div className="space-y-1">
          <h3 className="text-sm font-semibold text-zinc-200">Focus Timer</h3>
          <p className="text-xs text-zinc-400">Stay focused with timed work sessions</p>
        </div>
        
        <TimerDisplay remainingTime={remainingTime} status={state.status} />
        
        <TimerControls 
          state={state}
          onStart={start}
          onPause={pause}
          onResume={resume}
          onReset={reset}
        />
        
        <TimerSettings
          duration={state.duration}
          onDurationChange={setDuration}
          disabled={!canChangeDuration}
        />
      </div>
    </>
  );
}