export function App() {
  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-10 text-zinc-50">
      <section className="mx-auto flex max-w-md flex-col gap-5">
        <p className="text-sm font-medium uppercase tracking-wide text-cyan-300">
          Chronolog
        </p>
        <div className="space-y-3">
          <h1 className="text-4xl font-semibold leading-tight">
            Log time after it happens.
          </h1>
          <p className="text-base leading-7 text-zinc-300">
            Pick an activity when you remember what changed. Chronolog will use
            that timestamp to build the timeline.
          </p>
        </div>
      </section>
    </main>
  );
}
