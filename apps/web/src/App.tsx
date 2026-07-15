import { FormEvent, useCallback, useEffect, useRef, useState } from "react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Activity = {
  id: number;
  name: string;
  color: string;
  createdAt: string;
};

type Allocation = {
  activityId: number;
  percentage: number; // integer 0–100; all allocations sum to exactly 100
};

/** Shape returned by POST /time-blocks */
type TimeBlock = {
  id: number;
  startTime: string;
  endTime: string;
  createdAt: string;
  elapsedSeconds: number;
  allocations: Array<{
    id: number;
    activityId: number;
    percentage: number;
    durationSeconds: number;
    activity: Activity;
  }>;
};

// ─── Constants ────────────────────────────────────────────────────────────────

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";
const trackingStartedAtStorageKey = "chronolog.trackingStartedAt";
/** Minimum segment size in percentage points — prevents a segment from disappearing entirely. */
const MIN_SEGMENT_PCT = 2;

// ─── Pure helpers ─────────────────────────────────────────────────────────────

function formatTime(date: Date) {
  return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function formatElapsedClock(start: Date, end: Date) {
  const totalSeconds = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  return [h, m, s].map((v) => v.toString().padStart(2, "0")).join(":");
}

function formatMinutes(totalMinutes: number) {
  const mins = Math.round(totalMinutes);
  if (mins <= 0) return "0m";
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

function formatElapsedHumanShort(start: Date, end: Date) {
  const totalSeconds = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  if (h === 0 && m === 0) return "less than a minute";
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

/**
 * Seed equal-split allocations. Integer arithmetic: remainder goes to first.
 * e.g. 3 activities → [34, 33, 33]
 */
function buildEqualAllocations(activityIds: number[]): Allocation[] {
  const n = activityIds.length;
  if (n === 0) return [];
  const base = Math.floor(100 / n);
  const remainder = 100 - base * n;
  return activityIds.map((id, i) => ({
    activityId: id,
    percentage: base + (i === 0 ? remainder : 0),
  }));
}

/**
 * Given the current allocations, move divider at index `dividerIndex`
 * (the boundary between segment[dividerIndex] and segment[dividerIndex+1])
 * by `deltaPct` percentage points.
 *
 * Only the two neighbouring segments change. All others are untouched.
 * Min segment size is enforced via MIN_SEGMENT_PCT.
 */
function moveDivider(
  allocations: Allocation[],
  dividerIndex: number,
  deltaPct: number,
): Allocation[] {
  const left = allocations[dividerIndex];
  const right = allocations[dividerIndex + 1];
  if (!left || !right) return allocations;

  // How far can we actually move?
  const maxIncrease = right.percentage - MIN_SEGMENT_PCT; // left grows at right's expense
  const maxDecrease = left.percentage - MIN_SEGMENT_PCT;  // left shrinks at right's expense

  const actualDelta = Math.max(-maxDecrease, Math.min(maxIncrease, deltaPct));

  if (actualDelta === 0) return allocations;

  return allocations.map((a, i) => {
    if (i === dividerIndex) return { ...a, percentage: a.percentage + actualDelta };
    if (i === dividerIndex + 1) return { ...a, percentage: a.percentage - actualDelta };
    return a;
  });
}

// ─── AllocationBar ────────────────────────────────────────────────────────────

type AllocationBarProps = {
  activities: Activity[];
  allocations: Allocation[]; // must be same length as activities, in same order
  onChange: (updated: Allocation[]) => void;
};

/**
 * A single horizontal bar divided into coloured segments.
 * Each divider between adjacent segments is draggable.
 * Only the two neighbouring segments change when a divider moves.
 */
export function AllocationBar({ activities, allocations, onChange }: AllocationBarProps) {
  const barRef = useRef<HTMLDivElement>(null);
  // Which divider (0 = between seg 0 and seg 1) is being dragged, or null.
  const dragging = useRef<{
    dividerIndex: number;
    startX: number;
    startAllocations: Allocation[];
  } | null>(null);

  const activityMap = Object.fromEntries(activities.map((a) => [a.id, a]));

  // Convert a pixel delta to a percentage delta based on bar width.
  function pctFromPixelDelta(deltaX: number): number {
    const bar = barRef.current;
    if (!bar) return 0;
    const width = bar.getBoundingClientRect().width;
    return (deltaX / width) * 100;
  }

  const onPointerDown = useCallback(
    (dividerIndex: number) => (e: React.PointerEvent<HTMLDivElement>) => {
      e.preventDefault();
      e.stopPropagation();
      (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
      dragging.current = {
        dividerIndex,
        startX: e.clientX,
        startAllocations: allocations,
      };
    },
    [allocations],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      if (!dragging.current) return;
      const { dividerIndex, startX, startAllocations } = dragging.current;
      const deltaPct = pctFromPixelDelta(e.clientX - startX);
      const rounded = Math.round(deltaPct);
      if (rounded === 0) return;
      const updated = moveDivider(startAllocations, dividerIndex, rounded);
      onChange(updated);
      // Update the reference point so dragging feels anchored
      dragging.current = {
        dividerIndex,
        startX: e.clientX,
        startAllocations: updated,
      };
    },
    [onChange],
  );

  const onPointerUp = useCallback(() => {
    dragging.current = null;
  }, []);

  // Segments, rendered as adjacent flex children that share the full bar width.
  const segments = allocations.map((alloc) => activityMap[alloc.activityId]);

  return (
    <div>
      {/* ── The bar itself ─────────────────────────────────────────────── */}
      <div
        ref={barRef}
        className="relative flex h-10 w-full overflow-hidden rounded-xl touch-none select-none"
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        {allocations.map((alloc, i) => {
          const activity = segments[i];
          if (!activity) return null;
          const isLast = i === allocations.length - 1;

          return (
            <div
              key={alloc.activityId}
              className="relative h-full transition-none"
              style={{ width: `${alloc.percentage}%`, backgroundColor: activity.color }}
            >
              {/* Divider handle — only between adjacent segments, not after the last */}
              {!isLast ? (
                <div
                  className="absolute right-0 top-0 bottom-0 z-10 flex items-center justify-center"
                  style={{ width: "18px", transform: "translateX(50%)", cursor: "col-resize" }}
                  onPointerDown={onPointerDown(i)}
                >
                  {/* Visual grip pip */}
                  <div className="h-6 w-1.5 rounded-full bg-zinc-900/70 shadow-sm" />
                </div>
              ) : null}
            </div>
          );
        })}
      </div>

      {/* ── Legend ─────────────────────────────────────────────────────── */}
      {/* Rendered by parent; AllocationBar keeps itself pure */}
    </div>
  );
}

// ─── App ─────────────────────────────────────────────────────────────────────

type ModalView = "select" | "allocate";

export function App() {
  // Core data
  const [activities, setActivities] = useState<Activity[]>([]);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState("");

  // Activity creation form
  const [name, setName] = useState("");
  const [color, setColor] = useState("#38bdf8");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Session / timer
  const [trackingStartedAt, setTrackingStartedAt] = useState<string | null>(() =>
    localStorage.getItem(trackingStartedAtStorageKey),
  );
  const [now, setNow] = useState(() => new Date());

  // Log dialog — Step 1: select activities
  const [modalView, setModalView] = useState<ModalView>("select");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalElapsedText, setModalElapsedText] = useState("");
  const [modalTotalMinutes, setModalTotalMinutes] = useState(0);
  const [selectedActivityIds, setSelectedActivityIds] = useState<number[]>([]);

  // Log dialog — Step 2: allocate percentages
  const [allocations, setAllocations] = useState<Allocation[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [modalError, setModalError] = useState("");

  // Derived
  const hasTrackingStarted = trackingStartedAt !== null;
  const boundary = trackingStartedAt ? new Date(trackingStartedAt) : null;
  const timeSinceBoundary = boundary ? formatElapsedClock(boundary, now) : "00:00:00";
  const boundaryLabel = boundary ? `Started ${formatTime(boundary)}` : "Waiting to start";

  // ── Effects ──────────────────────────────────────────────────────────────

  useEffect(() => {
    fetch(`${apiUrl}/activities`)
      .then((r) => r.json() as Promise<Activity[]>)
      .then(setActivities)
      .catch(() => setError("Could not load activities."));
  }, []);

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);

  // ── Activity creation ─────────────────────────────────────────────────────

  async function createActivity(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setFeedback("");
    setIsSubmitting(true);
    try {
      const response = await fetch(`${apiUrl}/activities`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, color }),
      });
      const data = await response.json();
      if (!response.ok) {
        setError(data.error ?? "Could not create activity.");
        return;
      }
      setActivities((prev) => [...prev, data]);
      setName("");
      setFeedback(`Created ${data.name}.`);
    } catch {
      setError("Could not create activity.");
    } finally {
      setIsSubmitting(false);
    }
  }

  // ── Start tracking ────────────────────────────────────────────────────────

  function startTracking() {
    const startedAt = new Date().toISOString();
    localStorage.setItem(trackingStartedAtStorageKey, startedAt);
    setTrackingStartedAt(startedAt);
    setNow(new Date(startedAt));
    setFeedback(`Tracking started at ${formatTime(new Date(startedAt))}.`);
    setError("");
  }

  // ── Log dialog — Step 1 (select) ──────────────────────────────────────────

  function openModal() {
    if (!boundary) return;
    setModalElapsedText(formatElapsedHumanShort(boundary, now));
    setModalTotalMinutes(Math.max(0, (now.getTime() - boundary.getTime()) / 60000));
    setSelectedActivityIds([]);
    setAllocations([]);
    setModalView("select");
    setIsModalOpen(true);
  }

  function closeModal() {
    setIsModalOpen(false);
    setSelectedActivityIds([]);
    setAllocations([]);
    setModalError("");
    setIsSaving(false);
  }

  function toggleActivity(activityId: number) {
    setSelectedActivityIds((prev) =>
      prev.includes(activityId) ? prev.filter((id) => id !== activityId) : [...prev, activityId],
    );
  }

  function proceedToAllocate() {
    setAllocations(buildEqualAllocations(selectedActivityIds));
    setModalError("");
    setModalView("allocate");
  }

  // ── Log dialog — Step 2 (allocate) ───────────────────────────────────────

  async function handleSave() {
    if (isSaving) return; // guard against double-tap
    setIsSaving(true);
    setModalError("");

    try {
      const response = await fetch(`${apiUrl}/time-blocks`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          allocations: allocations.map((a) => ({
            activityId: a.activityId,
            percentage: a.percentage,
          })),
        }),
      });

      const data = (await response.json()) as TimeBlock | { error: string };

      if (!response.ok) {
        // Keep modal open; show the server's error message
        setModalError((data as { error: string }).error ?? "Could not save. Please try again.");
        return;
      }

      const block = data as TimeBlock;

      // Advance the tracking boundary to the server's end_time so the
      // next elapsed-time counter starts from exactly when this block ended.
      localStorage.setItem(trackingStartedAtStorageKey, block.endTime);
      setTrackingStartedAt(block.endTime);
      setNow(new Date(block.endTime));

      closeModal();
      setFeedback(`Saved — ${block.elapsedSeconds}s logged across ${block.allocations.length} activit${block.allocations.length === 1 ? "y" : "ies"}.`);
      setError("");
    } catch {
      setModalError("Network error. Check your connection and try again.");
    } finally {
      setIsSaving(false);
    }
  }

  // ─── Render ──────────────────────────────────────────────────────────────

  // Derive the ordered activity list that matches the current allocations order.
  const selectedActivities = allocations
    .map((a) => activities.find((act) => act.id === a.activityId))
    .filter((a): a is Activity => a !== undefined);

  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50">
      <section className="mx-auto flex max-w-md flex-col gap-7">

        {/* Header */}
        <header className="space-y-3">
          <p className="text-sm font-medium uppercase tracking-wide text-cyan-300">Chronolog</p>
          <div className="space-y-2">
            <h1 className="text-3xl font-semibold leading-tight">Activities</h1>
            <p className="text-base leading-7 text-zinc-300">
              Create the activities you want to track before logging time.
            </p>
          </div>
        </header>

        {/* Start tracking CTA */}
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

        {/* Live timer + Log Activity */}
        {hasTrackingStarted ? (
          <section className="rounded-md border border-zinc-800 bg-zinc-900 px-4 py-4">
            <div className="flex items-end justify-between gap-4">
              <div className="space-y-1">
                <h2 className="text-sm font-medium uppercase tracking-wide text-zinc-400">
                  Since last log
                </h2>
                <p className="text-4xl font-semibold tabular-nums text-zinc-50">
                  {timeSinceBoundary}
                </p>
              </div>
              <p className="pb-1 text-right text-sm text-zinc-400">{boundaryLabel}</p>
            </div>
            <button
              className="mt-4 w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 hover:bg-cyan-200 transition-colors duration-150 active:scale-[0.98]"
              onClick={openModal}
              type="button"
            >
              Log Activity
            </button>
          </section>
        ) : null}

        {/* Create activity form */}
        <form className="space-y-4" onSubmit={createActivity}>
          <label className="block space-y-2">
            <span className="text-sm font-medium text-zinc-200">Name</span>
            <input
              className="w-full rounded-md border border-zinc-700 bg-zinc-900 px-3 py-3 text-base text-zinc-50 outline-none focus:border-cyan-300"
              maxLength={100}
              onChange={(e) => setName(e.target.value)}
              placeholder="Study"
              value={name}
            />
          </label>
          <label className="block space-y-2">
            <span className="text-sm font-medium text-zinc-200">Color</span>
            <input
              className="h-12 w-20 rounded-md border border-zinc-700 bg-zinc-900 p-1"
              onChange={(e) => setColor(e.target.value)}
              type="color"
              value={color}
            />
          </label>

          {error ? <p className="text-sm text-red-300">{error}</p> : null}
          {feedback ? <p className="text-sm text-emerald-300">{feedback}</p> : null}

          <button
            className="w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isSubmitting}
            type="submit"
          >
            {isSubmitting ? "Adding…" : "Add activity"}
          </button>
        </form>

        {/* Saved activities */}
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
                  className="flex items-center gap-3 rounded-md border border-zinc-800 bg-zinc-900 px-4 py-3"
                  key={activity.id}
                >
                  <span
                    className="h-4 w-4 flex-none rounded-full"
                    style={{ backgroundColor: activity.color }}
                  />
                  <span className="truncate font-medium">{activity.name}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>

      {/* ── Modal overlay ────────────────────────────────────────────────────── */}
      {isModalOpen ? (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-zinc-950/80 backdrop-blur-sm p-4 sm:items-center"
          onClick={(e) => { if (e.target === e.currentTarget) closeModal(); }}
        >
          <div className="w-full max-w-md rounded-2xl border border-zinc-800 bg-zinc-900 shadow-2xl">

            {modalView === "select" ? (
              <SelectView
                activities={activities}
                elapsedText={modalElapsedText}
                selectedActivityIds={selectedActivityIds}
                onToggle={toggleActivity}
                onCancel={closeModal}
                onContinue={proceedToAllocate}
              />
            ) : (
              <AllocateView
                activities={selectedActivities}
                allocations={allocations}
                elapsedText={modalElapsedText}
                totalMinutes={modalTotalMinutes}
                onAllocationsChange={setAllocations}
                onBack={() => setModalView("select")}
                onSave={handleSave}
                isSaving={isSaving}
                saveError={modalError}
              />
            )}
          </div>
        </div>
      ) : null}
    </main>
  );
}

// ─── SelectView ───────────────────────────────────────────────────────────────

type SelectViewProps = {
  activities: Activity[];
  elapsedText: string;
  selectedActivityIds: number[];
  onToggle: (id: number) => void;
  onCancel: () => void;
  onContinue: () => void;
};

function SelectView({
  activities, elapsedText, selectedActivityIds, onToggle, onCancel, onContinue,
}: SelectViewProps) {
  return (
    <div className="flex flex-col">
      <div className="px-6 pt-6 pb-4">
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-1">
          How was the last
        </p>
        <p className="text-3xl font-bold text-zinc-50">{elapsedText}</p>
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mt-1">spent?</p>
      </div>

      <div className="h-px bg-zinc-800" />

      <div className="overflow-y-auto max-h-72 px-3 py-3 space-y-1">
        {activities.length === 0 ? (
          <p className="px-3 py-6 text-center text-sm text-zinc-500">No activities saved yet.</p>
        ) : (
          activities.map((activity) => {
            const checked = selectedActivityIds.includes(activity.id);
            return (
              <label
                key={activity.id}
                className={`flex items-center justify-between gap-3 rounded-xl px-4 py-3 cursor-pointer select-none transition-all duration-100 ${checked
                  ? "bg-zinc-800 border border-zinc-700"
                  : "bg-zinc-900/40 border border-transparent hover:bg-zinc-800/50"
                  }`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <span className="h-3 w-3 flex-none rounded-full" style={{ backgroundColor: activity.color }} />
                  <span className="truncate text-sm font-medium text-zinc-200">{activity.name}</span>
                </div>
                <input
                  type="checkbox"
                  checked={checked}
                  onChange={() => onToggle(activity.id)}
                  className="h-4 w-4 rounded accent-cyan-400 cursor-pointer"
                />
              </label>
            );
          })
        )}
      </div>

      <div className="h-px bg-zinc-800" />

      <div className="flex gap-3 px-6 py-4">
        <button
          type="button"
          onClick={onCancel}
          className="flex-1 rounded-xl border border-zinc-700 bg-zinc-900 py-3 text-sm font-semibold text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 transition-colors"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={onContinue}
          disabled={selectedActivityIds.length === 0}
          className="flex-1 rounded-xl bg-cyan-300 py-3 text-sm font-bold text-zinc-950 hover:bg-cyan-200 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          Continue
        </button>
      </div>
    </div>
  );
}

// ─── AllocateView ─────────────────────────────────────────────────────────────

type AllocateViewProps = {
  activities: Activity[]; // ordered to match allocations
  allocations: Allocation[];
  elapsedText: string;
  totalMinutes: number;
  onAllocationsChange: (updated: Allocation[]) => void;
  onBack: () => void;
  onSave: () => Promise<void>;
  isSaving: boolean;
  saveError: string;
};

function AllocateView({
  activities, allocations, elapsedText, totalMinutes,
  onAllocationsChange, onBack, onSave, isSaving, saveError,
}: AllocateViewProps) {
  return (
    <div className="flex flex-col">
      {/* Header */}
      <div className="px-6 pt-6 pb-4">
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-1">
          How was the last
        </p>
        <p className="text-3xl font-bold text-zinc-50">{elapsedText}</p>
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mt-1">spent?</p>
      </div>

      <div className="h-px bg-zinc-800" />

      {/* Allocation bar */}
      <div className="px-6 pt-5 pb-2">
        <AllocationBar
          activities={activities}
          allocations={allocations}
          onChange={onAllocationsChange}
        />
      </div>

      {/* Legend */}
      <div className="divide-y divide-zinc-800/60 px-6 pb-2">
        {allocations.map((alloc) => {
          const activity = activities.find((a) => a.id === alloc.activityId);
          if (!activity) return null;
          const mins = formatMinutes((alloc.percentage / 100) * totalMinutes);
          return (
            <div key={alloc.activityId} className="flex items-center justify-between gap-4 py-3">
              <div className="flex items-center gap-2.5 min-w-0">
                <span
                  className="h-3 w-3 flex-none rounded-full"
                  style={{ backgroundColor: activity.color }}
                />
                <span className="truncate text-sm font-semibold text-zinc-200">
                  {activity.name}
                </span>
              </div>
              <div className="flex items-baseline gap-3 shrink-0 tabular-nums">
                <span className="text-sm font-medium text-zinc-200">{mins}</span>
                <span className="text-xs font-semibold text-zinc-500 w-10 text-right">
                  {alloc.percentage}%
                </span>
              </div>
            </div>
          );
        })}
      </div>

      <div className="h-px bg-zinc-800" />

      {/* Inline error message */}
      {saveError ? (
        <p className="mx-6 mt-3 rounded-lg bg-red-950/60 border border-red-800 px-4 py-2.5 text-sm text-red-300">
          {saveError}
        </p>
      ) : null}

      {/* Footer */}
      <div className="flex gap-3 px-6 py-4">
        <button
          type="button"
          onClick={onBack}
          disabled={isSaving}
          className="flex-1 rounded-xl border border-zinc-700 bg-zinc-900 py-3 text-sm font-semibold text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onSave}
          disabled={isSaving}
          className="flex-1 rounded-xl bg-cyan-300 py-3 text-sm font-bold text-zinc-950 hover:bg-cyan-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isSaving ? "Saving…" : "Save"}
        </button>
      </div>
    </div>
  );
}
