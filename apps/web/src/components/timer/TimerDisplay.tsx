import { TimerState } from '../../types/timer';
import { formatTime } from '../../utils/timer';

interface TimerDisplayProps {
  remainingTime: number;
  status: TimerState['status'];
}

/**
 * Timer display showing remaining time and status
 */
export function TimerDisplay({ remainingTime, status }: TimerDisplayProps) {
  const displayTime = formatTime(remainingTime);
  
  return (
    <div className="space-y-2">
      <div className="text-center">
        <div className={`text-4xl font-mono font-bold tabular-nums ${
          status === 'completed' 
            ? 'text-emerald-400' 
            : status === 'running' 
              ? 'text-cyan-400' 
              : 'text-zinc-300'
        }`}>
          {displayTime}
        </div>
        <div className={`text-xs font-medium uppercase tracking-wide ${
          status === 'completed' 
            ? 'text-emerald-500' 
            : status === 'running' 
              ? 'text-cyan-500' 
              : status === 'paused'
                ? 'text-orange-500'
                : 'text-zinc-500'
        }`}>
          {status === 'completed' ? 'Session Complete!' : 
           status === 'running' ? 'Focus Mode' :
           status === 'paused' ? 'Paused' : 'Ready'}
        </div>
      </div>
    </div>
  );
}