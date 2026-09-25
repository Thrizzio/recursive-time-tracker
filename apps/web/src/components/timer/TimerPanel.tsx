import { useState } from 'react';
import { usePomodoro } from '../../hooks/usePomodoro';
import { formatTime } from '../../utils/timer';

function formatDurationSeconds(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) {
    return `${h}h ${m}m`;
  }
  if (m > 0) {
    return `${m}m ${sec}s`;
  }
  return `${sec}s`;
}

export function TimerPanel() {
  const [isExpanded, setIsExpanded] = useState(false);
  const {
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
  } = usePomodoro();

  // Setup form state
  const [focusMinutes, setFocusMinutes] = useState(25);
  const [shortBreakMinutes, setShortBreakMinutes] = useState(5);
  const [longBreakMinutes, setLongBreakMinutes] = useState(15);
  const [totalSessions, setTotalSessions] = useState(4);
  const [longBreakInterval, setLongBreakInterval] = useState(4);
  const [autoStartBreaks, setAutoStartBreaks] = useState(false);
  const [autoStartFocus, setAutoStartFocus] = useState(false);
  const [isStarting, setIsStarting] = useState(false);

  const isConfiguring =
    !plan || plan.status === 'completed' || plan.status === 'cancelled';

  const handleStartWork = async () => {
    setIsStarting(true);
    try {
      await start({
        focusDurationSeconds: focusMinutes * 60,
        shortBreakDurationSeconds: shortBreakMinutes * 60,
        longBreakDurationSeconds: longBreakMinutes * 60,
        totalSessions,
        longBreakInterval,
        autoStartBreaks,
        autoStartFocus,
      });
    } catch {
      // error handled in hook
    } finally {
      setIsStarting(false);
    }
  };

  const getPhaseBadge = (status: string, currentPhase: string) => {
    if (status === 'paused') {
      return {
        label: 'PAUSED',
        className: 'bg-amber-950/80 text-amber-300 border border-amber-800/60',
      };
    }
    if (currentPhase === 'focus') {
      return {
        label: 'FOCUS PHASE',
        className: 'bg-cyan-950/80 text-cyan-300 border border-cyan-800/60',
      };
    }
    if (currentPhase === 'longBreak') {
      return {
        label: 'LONG BREAK',
        className: 'bg-indigo-950/80 text-indigo-300 border border-indigo-800/60',
      };
    }
    return {
      label: 'SHORT BREAK',
      className: 'bg-emerald-950/80 text-emerald-300 border border-emerald-800/60',
    };
  };

  return (
    <>
      {/* Mobile: Collapsible header */}
      <div className="lg:hidden">
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className="w-full rounded-xl border border-zinc-800 bg-zinc-900 px-4 py-3 text-left hover:bg-zinc-800/60 transition-colors"
          aria-expanded={isExpanded}
          aria-label="Toggle pomodoro panel"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-sm font-semibold text-zinc-100 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-cyan-400" />
                Focus Session
              </div>
              {!isConfiguring && (
                <>
                  <div className="text-xs font-mono font-bold text-zinc-300">
                    {formatTime(remainingSeconds * 1000)}
                  </div>
                  {(() => {
                    const badge = getPhaseBadge(plan.status, plan.currentPhase);
                    return (
                      <span
                        className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${badge.className}`}
                      >
                        {badge.label}
                      </span>
                    );
                  })()}
                </>
              )}
            </div>
            <svg
              className={`h-4 w-4 text-zinc-400 transition-transform ${
                isExpanded ? 'rotate-180' : ''
              }`}
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
          <div className="mt-3 rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-4">
            {renderPanelContent()}
          </div>
        )}
      </div>

      {/* Desktop: Always visible panel */}
      <div className="hidden lg:block rounded-xl border border-zinc-800 bg-zinc-900 p-4 space-y-4">
        {renderPanelContent()}
      </div>
    </>
  );

  function renderPanelContent() {
    if (loading) {
      return (
        <div className="py-8 flex flex-col items-center justify-center space-y-2 text-zinc-400">
          <div className="w-6 h-6 border-2 border-cyan-400 border-t-transparent rounded-full animate-spin" />
          <span className="text-xs">Loading focus plan...</span>
        </div>
      );
    }

    if (error) {
      return (
        <div className="p-3 rounded-lg bg-red-950/40 border border-red-800/50 text-red-300 text-xs">
          {error}
        </div>
      );
    }

    // ── Mode 1: Configuration Form ("I WILL WORK") ───────────────────────────
    if (isConfiguring) {
      const isCompleted = plan?.status === 'completed';

      return (
        <div className="space-y-4">
          <div className="space-y-1">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-bold text-zinc-100 flex items-center gap-2">
                <svg
                  className="w-4 h-4 text-cyan-400"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  viewBox="0 0 24 24"
                >
                  <circle cx="12" cy="12" r="10" />
                  <polyline points="12 6 12 12 16 14" />
                </svg>
                Focus Session Setup
              </h3>
              {isCompleted && (
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-950 text-emerald-400 border border-emerald-800/60">
                  Completed!
                </span>
              )}
            </div>
            <p className="text-xs text-zinc-400">
              Configure your intervals and commit to deep work.
            </p>
          </div>

          {isCompleted && (
            <div className="p-3 rounded-lg bg-emerald-950/30 border border-emerald-800/40 space-y-1 text-xs">
              <p className="font-semibold text-emerald-300">
                🎉 Great job! You finished {plan.completedSessions} focus{' '}
                {plan.completedSessions === 1 ? 'session' : 'sessions'}.
              </p>
              <p className="text-zinc-400">
                Focus: {formatDurationSeconds(plan.totalFocusSeconds)} • Break:{' '}
                {formatDurationSeconds(plan.totalBreakSeconds)} • Paused:{' '}
                {formatDurationSeconds(plan.totalPausedSeconds)}
              </p>
            </div>
          )}

          {/* Focus Duration Selection */}
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs">
              <span className="text-zinc-300 font-medium">Focus Duration</span>
              <span className="text-cyan-400 font-bold">{focusMinutes} min</span>
            </div>
            <div className="grid grid-cols-4 gap-1.5">
              {[15, 25, 45, 50].map((mins) => (
                <button
                  key={mins}
                  type="button"
                  onClick={() => setFocusMinutes(mins)}
                  className={`py-1.5 text-xs font-semibold rounded-lg border transition-all ${
                    focusMinutes === mins
                      ? 'bg-cyan-950 text-cyan-300 border-cyan-500/80 shadow-sm shadow-cyan-900/40'
                      : 'bg-zinc-800/60 text-zinc-400 border-zinc-700/60 hover:bg-zinc-800'
                  }`}
                >
                  {mins}m
                </button>
              ))}
            </div>
          </div>

          {/* Breaks Selection */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs">
                <span className="text-zinc-300 font-medium">Short Break</span>
                <span className="text-emerald-400 font-bold">{shortBreakMinutes}m</span>
              </div>
              <div className="grid grid-cols-2 gap-1.5">
                {[5, 10].map((m) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => setShortBreakMinutes(m)}
                    className={`py-1 text-xs font-medium rounded-lg border ${
                      shortBreakMinutes === m
                        ? 'bg-emerald-950 text-emerald-300 border-emerald-500/80'
                        : 'bg-zinc-800/60 text-zinc-400 border-zinc-700/60 hover:bg-zinc-800'
                    }`}
                  >
                    {m}m
                  </button>
                ))}
              </div>
            </div>

            <div className="space-y-1.5">
              <div className="flex justify-between text-xs">
                <span className="text-zinc-300 font-medium">Long Break</span>
                <span className="text-indigo-400 font-bold">{longBreakMinutes}m</span>
              </div>
              <div className="grid grid-cols-2 gap-1.5">
                {[15, 20].map((m) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => setLongBreakMinutes(m)}
                    className={`py-1 text-xs font-medium rounded-lg border ${
                      longBreakMinutes === m
                        ? 'bg-indigo-950 text-indigo-300 border-indigo-500/80'
                        : 'bg-zinc-800/60 text-zinc-400 border-zinc-700/60 hover:bg-zinc-800'
                    }`}
                  >
                    {m}m
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Session Count & Interval */}
          <div className="grid grid-cols-2 gap-3 pt-1">
            <div className="space-y-1">
              <label className="text-xs text-zinc-300 font-medium">
                Total Sessions
              </label>
              <select
                value={totalSessions}
                onChange={(e) => setTotalSessions(Number(e.target.value))}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-2.5 py-1.5 text-xs text-zinc-200 focus:outline-none focus:border-cyan-500"
              >
                {[2, 3, 4, 6, 8].map((n) => (
                  <option key={n} value={n}>
                    {n} sessions
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-1">
              <label className="text-xs text-zinc-300 font-medium">
                Long Break Every
              </label>
              <select
                value={longBreakInterval}
                onChange={(e) => setLongBreakInterval(Number(e.target.value))}
                className="w-full bg-zinc-800 border border-zinc-700 rounded-lg px-2.5 py-1.5 text-xs text-zinc-200 focus:outline-none focus:border-cyan-500"
              >
                {[2, 3, 4].map((n) => (
                  <option key={n} value={n}>
                    {n}th session
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Auto-start options */}
          <div className="space-y-2 pt-1">
            <label className="flex items-center gap-2.5 text-xs text-zinc-300 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={autoStartBreaks}
                onChange={(e) => setAutoStartBreaks(e.target.checked)}
                className="rounded border-zinc-700 bg-zinc-800 text-cyan-500 focus:ring-0 w-3.5 h-3.5"
              />
              Auto-start breaks
            </label>
            <label className="flex items-center gap-2.5 text-xs text-zinc-300 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={autoStartFocus}
                onChange={(e) => setAutoStartFocus(e.target.checked)}
                className="rounded border-zinc-700 bg-zinc-800 text-cyan-500 focus:ring-0 w-3.5 h-3.5"
              />
              Auto-start focus sessions
            </label>
          </div>

          {/* Prominent "I WILL WORK" Button */}
          <button
            type="button"
            disabled={isStarting}
            onClick={handleStartWork}
            className="w-full mt-2 py-3 px-4 rounded-xl font-extrabold text-sm tracking-wider uppercase bg-gradient-to-r from-cyan-400 to-cyan-300 hover:from-cyan-300 hover:to-cyan-200 text-zinc-950 shadow-md shadow-cyan-500/20 hover:shadow-cyan-500/30 transition-all flex items-center justify-center gap-2 active:scale-[0.99] disabled:opacity-50 cursor-pointer"
          >
            {isStarting ? (
              <div className="w-5 h-5 border-2 border-zinc-950 border-t-transparent rounded-full animate-spin" />
            ) : (
              <>
                <svg
                  className="w-5 h-5 fill-current"
                  viewBox="0 0 24 24"
                >
                  <polygon points="5 3 19 12 5 21 5 3" />
                </svg>
                I WILL WORK
              </>
            )}
          </button>
        </div>
      );
    }

    // ── Mode 2: Active Session View ──────────────────────────────────────────
    const badge = getPhaseBadge(plan.status, plan.currentPhase);
    const isPaused = plan.status === 'paused';

    return (
      <div className="space-y-4">
        {/* Header with Phase and Session Counter */}
        <div className="flex items-center justify-between">
          <span
            className={`text-xs font-bold px-2.5 py-1 rounded-full uppercase tracking-wider ${badge.className}`}
          >
            {badge.label}
          </span>
          <span className="text-xs font-semibold text-zinc-400">
            Session {plan.currentSession} of {plan.totalSessions}
          </span>
        </div>

        {/* Task name if attached */}
        {plan.taskTitle && (
          <div className="px-3 py-1.5 rounded-lg bg-zinc-800/60 border border-zinc-700/40 text-xs text-zinc-300 flex items-center gap-2 truncate">
            <svg
              className="w-3.5 h-3.5 text-cyan-400 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <path d="M9 11l3 3L22 4" />
              <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" />
            </svg>
            <span className="truncate">{plan.taskTitle}</span>
          </div>
        )}

        {/* Digital Countdown Timer */}
        <div className="text-center py-2">
          <div className="text-4xl sm:text-5xl font-mono font-extrabold text-zinc-50 tracking-tight">
            {formatTime(remainingSeconds * 1000)}
          </div>
          <div className="text-[11px] text-zinc-500 uppercase tracking-widest mt-1">
            {isPaused ? 'Timer Paused' : 'Time Remaining'}
          </div>
        </div>

        {/* Distinct Time Accounting (Segregated Focus, Break, Paused) */}
        <div className="grid grid-cols-3 gap-2 py-2 px-1 rounded-xl bg-zinc-950/60 border border-zinc-800/80">
          <div className="text-center">
            <div className="text-[10px] uppercase font-bold text-cyan-400/80">
              Focus
            </div>
            <div className="text-xs font-mono font-bold text-zinc-200 mt-0.5">
              {formatDurationSeconds(liveStats.totalFocus)}
            </div>
          </div>
          <div className="text-center border-x border-zinc-800">
            <div className="text-[10px] uppercase font-bold text-emerald-400/80">
              Break
            </div>
            <div className="text-xs font-mono font-bold text-zinc-200 mt-0.5">
              {formatDurationSeconds(liveStats.totalBreak)}
            </div>
          </div>
          <div className="text-center">
            <div className="text-[10px] uppercase font-bold text-amber-400/80">
              Paused
            </div>
            <div className="text-xs font-mono font-bold text-zinc-200 mt-0.5">
              {formatDurationSeconds(liveStats.totalPaused)}
            </div>
          </div>
        </div>

        {/* Controls */}
        <div className="flex items-center gap-2 pt-1">
          {isPaused ? (
            <button
              type="button"
              onClick={resume}
              className="flex-1 py-2.5 px-3 rounded-lg bg-cyan-500 hover:bg-cyan-400 text-zinc-950 font-bold text-xs flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
            >
              <svg className="w-4 h-4 fill-current" viewBox="0 0 24 24">
                <polygon points="5 3 19 12 5 21 5 3" />
              </svg>
              Resume
            </button>
          ) : (
            <button
              type="button"
              onClick={pause}
              className="flex-1 py-2.5 px-3 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200 font-bold text-xs border border-zinc-700 flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
            >
              <svg className="w-4 h-4 fill-current" viewBox="0 0 24 24">
                <rect x="6" y="4" width="4" height="16" />
                <rect x="14" y="4" width="4" height="16" />
              </svg>
              Pause
            </button>
          )}

          <button
            type="button"
            onClick={skip}
            title="Skip current phase"
            className="py-2.5 px-3 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-300 font-medium text-xs border border-zinc-700 flex items-center justify-center gap-1 transition-colors cursor-pointer"
          >
            <svg
              className="w-4 h-4"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <polygon points="5 4 15 12 5 20 5 4" fill="currentColor" />
              <line x1="19" y1="5" x2="19" y2="19" />
            </svg>
            Skip
          </button>

          <button
            type="button"
            onClick={cancel}
            title="Stop & cancel session"
            className="py-2.5 px-3 rounded-lg bg-zinc-800 hover:bg-red-950/40 hover:text-red-400 text-zinc-400 font-medium text-xs border border-zinc-700 transition-colors cursor-pointer"
          >
            <svg
              className="w-4 h-4"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <rect x="5" y="5" width="14" height="14" rx="2" fill="currentColor" />
            </svg>
          </button>
        </div>
      </div>
    );
  }
}