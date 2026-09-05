export default function AppLoading() {
  return (
    <div className="page-stack animate-pulse">
      <div className="space-y-2">
        <div className="h-8 w-48 rounded-lg bg-[var(--border)]" />
        <div className="h-4 w-72 max-w-full rounded-md bg-[var(--border)]" />
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="surface h-20 rounded-[var(--radius-lg)] bg-[var(--surface)]"
          />
        ))}
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="surface h-24 rounded-[var(--radius-lg)] bg-[var(--surface)]"
          />
        ))}
      </div>

      <div className="surface h-64 rounded-[var(--radius-lg)] bg-[var(--surface)]" />
    </div>
  );
}
