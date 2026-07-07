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

                  <button
                    className="rounded-md bg-zinc-800 px-3 py-2 text-sm font-medium text-zinc-100 disabled:cursor-not-allowed disabled:opacity-60"
                    disabled={!hasTrackingStarted || isLoggingId === activity.id}
                    onClick={() => logActivity(activity)}
                    type="button"
                  >
                    {isLoggingId === activity.id ? "Logging..." : "Log"}
                  </button>
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
    </main>
  );
}
