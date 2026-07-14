import { FormEvent, useEffect, useState } from "react";

type Activity = {
  id: number;
  name: string;
  color: string;
  createdAt: string;
};

type TimeLog = {
  id: number;
  activityId: number;
  loggedAt: string;
  createdAt: string;
  activity: {
    id: number;
    name: string;
    color: string;
  };
};

type TimelineInterval = {
  id: string;
  activity: TimeLog["activity"];
  start: Date;
  end: Date;
};

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";
const trackingStartedAtStorageKey = "chronolog.trackingStartedAt";

function formatTime(date: Date) {
  return date.toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
}

function formatDuration(start: Date, end: Date) {
  const minutes = Math.max(0, Math.round((end.getTime() - start.getTime()) / 60000));

  if (minutes < 1) {
    return "Less than 1 min";
  }

  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;

  if (hours === 0) {
    return `${minutes} min`;
  }

  if (remainingMinutes === 0) {
    return `${hours} hr`;
  }

  return `${hours} hr ${remainingMinutes} min`;
}

function formatElapsedTime(start: Date, end: Date) {
  const totalSeconds = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  return [hours, minutes, seconds]
    .map((value) => value.toString().padStart(2, "0"))
    .join(":");
}

function formatElapsedHoursMinutes(start: Date, end: Date) {
  const totalSeconds = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);

  if (hours === 0 && minutes === 0) {
    return "less than a minute";
  }
  if (hours === 0) {
    return `${minutes}m`;
  }
  if (minutes === 0) {
    return `${hours}h`;
  }
  return `${hours}h ${minutes}m`;
}

function buildTimelineIntervals(logs: TimeLog[], trackingStartedAt: string | null) {
  const intervals: TimelineInterval[] = [];

  for (let index = 0; index < logs.length; index += 1) {
    const currentLog = logs[index];
    const previousLog = logs[index - 1];
    const start = previousLog?.loggedAt ?? trackingStartedAt;

    if (!start) {
      continue;
    }

    intervals.push({
      id: `closed-${currentLog.id}`,
      activity: currentLog.activity,
      start: new Date(start),
      end: new Date(currentLog.loggedAt),
    });
  }

  return intervals.reverse();
}

function getLastLogBoundary(logs: TimeLog[], trackingStartedAt: string | null) {
  return logs.at(-1)?.loggedAt ?? trackingStartedAt;
}

export function App() {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [timeLogs, setTimeLogs] = useState<TimeLog[]>([]);
  const [name, setName] = useState("");
  const [color, setColor] = useState("#38bdf8");
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoggingId, setIsLoggingId] = useState<number | null>(null);
  const [trackingStartedAt, setTrackingStartedAt] = useState<string | null>(() =>
    localStorage.getItem(trackingStartedAtStorageKey),
  );
  const [now, setNow] = useState(() => new Date());
  const [isLogModalOpen, setIsLogModalOpen] = useState(false);
  const [selectedActivityIds, setSelectedActivityIds] = useState<number[]>([]);
  const [modalElapsedText, setModalElapsedText] = useState("");

  const timelineIntervals = buildTimelineIntervals(timeLogs, trackingStartedAt);
  const hasTrackingStarted = trackingStartedAt !== null || timeLogs.length > 0;
  const lastLogBoundary = getLastLogBoundary(timeLogs, trackingStartedAt);
  const timeSinceLastLog = lastLogBoundary
    ? formatElapsedTime(new Date(lastLogBoundary), now)
    : "00:00:00";

  useEffect(() => {
    async function loadInitialData() {
      const [activitiesResponse, timeLogsResponse] = await Promise.all([
        fetch(`${apiUrl}/activities`),
        fetch(`${apiUrl}/time-logs`),
      ]);

      if (!activitiesResponse.ok || !timeLogsResponse.ok) {
        throw new Error("Could not load initial data.");
      }

      const activitiesData = (await activitiesResponse.json()) as Activity[];
      const timeLogsData = (await timeLogsResponse.json()) as TimeLog[];

      setActivities(activitiesData);
      setTimeLogs(timeLogsData);
    }

    loadInitialData().catch(() => {
      setError("Could not load Chronolog data.");
    });
  }, []);

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      setNow(new Date());
    }, 1000);

    return () => window.clearInterval(intervalId);
  }, []);

  function startTracking() {
    const startedAt = new Date().toISOString();

    localStorage.setItem(trackingStartedAtStorageKey, startedAt);
    setTrackingStartedAt(startedAt);
    setNow(new Date(startedAt));
    setFeedback(`Tracking started at ${formatTime(new Date(startedAt))}.`);
    setError("");
  }

  async function createActivity(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setFeedback("");
    setIsSubmitting(true);

    try {
      const response = await fetch(`${apiUrl}/activities`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ name, color }),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.error ?? "Could not create activity.");
        return;
      }

      setActivities((currentActivities) => [...currentActivities, data]);
      setName("");
      setFeedback(`Created ${data.name}.`);
    } catch {
      setError("Could not create activity.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function logActivity(activity: Activity) {
    setError("");
    setFeedback("");
    setIsLoggingId(activity.id);
    const logStartedAt = lastLogBoundary ? new Date(lastLogBoundary) : null;

    try {
      const response = await fetch(`${apiUrl}/time-logs`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ activityId: activity.id }),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.error ?? "Could not log activity.");
        return;
      }

      setTimeLogs((currentLogs) => [
        ...currentLogs,
        {
          ...data,
          activity: {
            id: activity.id,
            name: activity.name,
            color: activity.color,
          },
        },
      ]);
      setNow(new Date());
      const loggedAt = new Date(data.loggedAt);
      const elapsed = logStartedAt ? formatDuration(logStartedAt, loggedAt) : "0 min";

      setFeedback(
        `Logged ${elapsed} as ${activity.name} at ${formatTime(loggedAt)}.`,
      );
    } catch {
      setError("Could not log activity.");
    } finally {
      setIsLoggingId(null);
    }
  }

  function handleOpenLogDialog() {
    if (!lastLogBoundary) return;
    const elapsed = formatElapsedHoursMinutes(new Date(lastLogBoundary), now);
    setModalElapsedText(elapsed);
    setSelectedActivityIds([]);
    setIsLogModalOpen(true);
  }

  function handleCloseLogDialog() {
    setIsLogModalOpen(false);
    setSelectedActivityIds([]);
  }

  function handleContinueLogDialog() {
    setIsLogModalOpen(false);
  }

  function handleToggleActivity(activityId: number) {
    setSelectedActivityIds((prev) =>
      prev.includes(activityId)
        ? prev.filter((id) => id !== activityId)
        : [...prev, activityId]
    );
  }

  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50">
      <section className="mx-auto flex max-w-md flex-col gap-7">
        <header className="space-y-3">
          <p className="text-sm font-medium uppercase tracking-wide text-cyan-300">
            Chronolog
          </p>
          <div className="space-y-2">
            <h1 className="text-3xl font-semibold leading-tight">Activities</h1>
            <p className="text-base leading-7 text-zinc-300">
              Create the activities you want to track before logging time.
            </p>
          </div>
        </header>

        {!hasTrackingStarted ? (
          <section className="space-y-3 rounded-md border border-cyan-700 bg-cyan-950/40 px-4 py-4">
            <div className="space-y-1">
              <h2 className="text-lg font-semibold">Start tracking</h2>
              <p className="text-sm leading-6 text-cyan-100">
                Press this once when you want Chronolog to begin counting time.
              </p>
            </div>

            <button
              className="w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950"
              onClick={startTracking}
              type="button"
            >
              Start tracking
            </button>
          </section>
        ) : null}

        {hasTrackingStarted ? (
          <section className="rounded-md border border-zinc-800 bg-zinc-900 px-4 py-4">
            <div className="flex items-end justify-between gap-4">
              <div className="space-y-1">
                <h2 className="text-sm font-medium uppercase tracking-wide text-zinc-400">
                  Since last log
                </h2>
                <p className="text-4xl font-semibold tabular-nums text-zinc-50">
                  {timeSinceLastLog}
                </p>
              </div>

              <p className="pb-1 text-right text-sm text-zinc-400">
                {lastLogBoundary
                  ? `Started ${formatTime(new Date(lastLogBoundary))}`
                  : "Waiting to start"}
              </p>
            </div>

            <button
              className="mt-4 w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 hover:bg-cyan-200 transition-all duration-150 active:scale-98 disabled:cursor-not-allowed disabled:opacity-60"
              onClick={handleOpenLogDialog}
              type="button"
            >
              Log Activity
            </button>
          </section>
        ) : null}

        <form className="space-y-4" onSubmit={createActivity}>
          <label className="block space-y-2">
            <span className="text-sm font-medium text-zinc-200">Name</span>
            <input
              className="w-full rounded-md border border-zinc-700 bg-zinc-900 px-3 py-3 text-base text-zinc-50 outline-none focus:border-cyan-300"
              maxLength={100}
              onChange={(event) => setName(event.target.value)}
              placeholder="Study"
              value={name}
            />
          </label>

          <label className="block space-y-2">
            <span className="text-sm font-medium text-zinc-200">Color</span>
            <input
              className="h-12 w-20 rounded-md border border-zinc-700 bg-zinc-900 p-1"
              onChange={(event) => setColor(event.target.value)}
              type="color"
              value={color}
            />
          </label>

          {error ? <p className="text-sm text-red-300">{error}</p> : null}
          {feedback ? (
            <p className="text-sm text-emerald-300">{feedback}</p>
          ) : null}

          <button
            className="w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isSubmitting}
            type="submit"
          >
            {isSubmitting ? "Adding..." : "Add activity"}
          </button>
        </form>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Saved activities</h2>

          {activities.length === 0 ? (
            <p className="rounded-md border border-dashed border-zinc-700 px-4 py-5 text-sm text-zinc-400">
              No activities yet.
            </p>
          ) : (
            <ul className="space-y-3">
              {activities.map((activity) => (
                <li
                  className="flex items-center justify-between gap-3 rounded-md border border-zinc-800 bg-zinc-900 px-4 py-3"
                  key={activity.id}
                >
                  <div className="flex min-w-0 items-center gap-3">
                    <span
                      className="h-4 w-4 flex-none rounded-full"
                      style={{ backgroundColor: activity.color }}
                    />
                    <span className="truncate font-medium">{activity.name}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="space-y-3">
          <div className="flex items-end justify-between gap-3">
            <h2 className="text-lg font-semibold">Timeline</h2>
            {timelineIntervals.length > 0 ? (
              <p className="text-sm text-zinc-400">
                {timelineIntervals.length} intervals
              </p>
            ) : null}
          </div>

          {timelineIntervals.length === 0 ? (
            <p className="rounded-md border border-dashed border-zinc-700 px-4 py-5 text-sm text-zinc-400">
              {hasTrackingStarted
                ? "Log an activity to create your first interval."
                : "Start tracking to begin the timeline."}
            </p>
          ) : (
            <ul className="space-y-3">
              {timelineIntervals.map((interval) => (
                <li
                  className="rounded-md border border-zinc-800 bg-zinc-900 px-4 py-3"
                  key={interval.id}
                >
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <span
                        className="h-4 w-4 flex-none rounded-full"
                        style={{ backgroundColor: interval.activity.color }}
                      />
                      <span className="truncate font-medium">
                        {interval.activity.name}
                      </span>
                    </div>

                    <span className="text-sm text-zinc-400">
                      {formatDuration(interval.start, interval.end)}
                    </span>
                  </div>

                  <div className="mt-3 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-zinc-400">
                    <span>{formatTime(interval.start)}</span>
                    <span>to</span>
                    <span>{formatTime(interval.end)}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>

      {isLogModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-zinc-950/80 backdrop-blur-md p-4">
          <div className="w-full max-w-md rounded-2xl border border-zinc-800 bg-zinc-900/95 p-6 shadow-2xl backdrop-blur-xl animate-in fade-in zoom-in-95 duration-200">
            <h2 className="text-xl font-bold text-zinc-50 leading-tight mb-2">
              How did you spend the last {modalElapsedText}?
            </h2>
            <p className="text-sm text-zinc-400 mb-6">
              Select one or more activities to attribute this time block to.
            </p>

            <div className="space-y-2 max-h-60 overflow-y-auto mb-6 pr-1 custom-scrollbar">
              {activities.length === 0 ? (
                <p className="rounded-md border border-dashed border-zinc-700 px-4 py-5 text-sm text-zinc-400 text-center">
                  No activities saved yet.
                </p>
              ) : (
                activities.map((activity) => {
                  const isChecked = selectedActivityIds.includes(activity.id);
                  return (
                    <label
                      key={activity.id}
                      className="flex items-center justify-between p-3.5 rounded-xl border border-zinc-850 bg-zinc-950/60 hover:bg-zinc-800/40 hover:border-zinc-700/60 cursor-pointer select-none transition-all duration-150"
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        <span
                          className="h-3.5 w-3.5 flex-none rounded-full"
                          style={{ backgroundColor: activity.color }}
                        />
                        <span className="truncate font-medium text-zinc-200">
                          {activity.name}
                        </span>
                      </div>
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={() => handleToggleActivity(activity.id)}
                        className="h-5 w-5 rounded border-zinc-700 bg-zinc-900 text-cyan-400 focus:ring-cyan-400 focus:ring-offset-zinc-900 cursor-pointer accent-cyan-400"
                      />
                    </label>
                  );
                })
              )}
            </div>

            <div className="flex items-center justify-end gap-3 border-t border-zinc-800/60 pt-4">
              <button
                type="button"
                onClick={handleCloseLogDialog}
                className="rounded-xl border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800 px-5 py-2.5 text-sm font-semibold text-zinc-300 hover:text-zinc-50 transition-all active:scale-97 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleContinueLogDialog}
                disabled={selectedActivityIds.length === 0}
                className="rounded-xl bg-cyan-300 hover:bg-cyan-200 disabled:opacity-40 disabled:hover:bg-cyan-300 disabled:cursor-not-allowed px-5 py-2.5 text-sm font-bold text-zinc-950 transition-all active:scale-97 cursor-pointer"
              >
                Continue
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
