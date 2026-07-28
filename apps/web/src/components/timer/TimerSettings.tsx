import { useState } from 'react';
import { TIMER_PRESETS, minutesToMilliseconds } from '../../utils/timer';

interface TimerSettingsProps {
  duration: number;
  onDurationChange: (milliseconds: number) => void;
  disabled: boolean;
}

/**
 * Timer settings component with preset durations and custom input
 */
export function TimerSettings({ 
  duration, 
  onDurationChange, 
  disabled 
}: TimerSettingsProps) {
  const [customMinutes, setCustomMinutes] = useState('');
  
  const handleCustomSubmit = () => {
    const minutes = parseInt(customMinutes);
    if (minutes >= 1 && minutes <= 180) {
      onDurationChange(minutesToMilliseconds(minutes));
      setCustomMinutes('');
    }
  };
  
  const isCustomInputValid = () => {
    const minutes = parseInt(customMinutes);
    return !isNaN(minutes) && minutes >= 1 && minutes <= 180;
  };
  
  return (
    <div className="space-y-3">
      {/* Preset buttons */}
      <div className="flex gap-2">
        {TIMER_PRESETS.map((preset) => (
          <button
            key={preset.label}
            onClick={() => onDurationChange(preset.duration)}
            disabled={disabled}
            className={`flex-1 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              duration === preset.duration
                ? 'bg-zinc-700 text-zinc-100 border border-zinc-600'
                : 'bg-zinc-800 text-zinc-300 border border-zinc-700 hover:bg-zinc-700 hover:text-zinc-100'
            } ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
            aria-label={`Set timer to ${preset.label}`}
          >
            {preset.label}
          </button>
        ))}
      </div>
      
      {/* Custom duration input */}
      <div className="flex gap-2">
        <input
          type="number"
          min="1"
          max="180"
          value={customMinutes}
          onChange={(e) => setCustomMinutes(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && isCustomInputValid() && !disabled) {
              handleCustomSubmit();
            }
          }}
          placeholder="Custom minutes"
          disabled={disabled}
          className="flex-1 rounded-lg border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm text-zinc-50 placeholder-zinc-400 outline-none focus:border-cyan-400 disabled:opacity-50 disabled:cursor-not-allowed"
          aria-label="Custom timer duration in minutes"
        />
        <button
          onClick={handleCustomSubmit}
          disabled={disabled || !customMinutes || !isCustomInputValid()}
          className="rounded-lg bg-zinc-700 px-3 py-2 text-sm font-medium text-zinc-300 hover:bg-zinc-600 hover:text-zinc-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          aria-label="Set custom timer duration"
        >
          Set
        </button>
      </div>
      
      {/* Validation hint */}
      {customMinutes && !isCustomInputValid() && (
        <p className="text-xs text-red-400">
          Please enter a duration between 1 and 180 minutes
        </p>
      )}
    </div>
  );
}