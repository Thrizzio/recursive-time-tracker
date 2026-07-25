import { Link } from 'react-router-dom';
import { GoogleTask } from '../../types/tasks';

interface TaskPanelProps {
  tasks: GoogleTask[];
  loading: boolean;
  error: string;
  hasSelectedList: boolean;
}

export function TaskPanel({ tasks, loading, error, hasSelectedList }: TaskPanelProps) {
  if (loading) {
    return (
      <aside className="w-64 flex-shrink-0 hidden xl:block">
        <div className="rounded-lg border border-zinc-700 bg-zinc-900 p-4">
          <h3 className="text-sm font-semibold text-zinc-200 mb-3">Tasks</h3>
          <div className="animate-pulse space-y-2">
            <div className="h-12 bg-zinc-800 rounded" />
            <div className="h-12 bg-zinc-800 rounded" />
          </div>
        </div>
      </aside>
    );
  }

  if (error) {
    return (
      <aside className="w-64 flex-shrink-0 hidden xl:block">
        <div className="rounded-lg border border-zinc-700 bg-zinc-900 p-4 space-y-3">
          <h3 className="text-sm font-semibold text-zinc-200">Tasks</h3>
          <p className="text-xs text-red-400">{error}</p>
          <Link
            to="/settings"
            className="text-xs text-cyan-400 hover:underline"
          >
            Check settings
          </Link>
        </div>
      </aside>
    );
  }

  if (!hasSelectedList) {
    return (
      <aside className="w-64 flex-shrink-0 hidden xl:block">
        <div className="rounded-lg border border-zinc-700 bg-zinc-900 p-4 space-y-3">
          <h3 className="text-sm font-semibold text-zinc-200">Tasks</h3>
          <p className="text-xs text-zinc-400">
            No task list selected.
          </p>
          <Link
            to="/settings"
            className="block w-full text-center rounded-lg bg-cyan-700 px-3 py-2 text-xs font-medium text-zinc-50 hover:bg-cyan-600 transition-colors"
          >
            Select Task List
          </Link>
        </div>
      </aside>
    );
  }

  return (
    <aside className="w-64 flex-shrink-0 hidden xl:block">
      <div className="rounded-lg border border-zinc-700 bg-zinc-900 p-4 space-y-3 sticky top-8">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold text-zinc-200">Tasks</h3>
          <Link
            to="/settings"
            className="text-xs text-zinc-400 hover:text-zinc-200"
            title="Change task list"
          >
            <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </Link>
        </div>
        
        {tasks.length === 0 ? (
          <p className="text-xs text-zinc-400">No incomplete tasks.</p>
        ) : (
          <div className="space-y-2 max-h-96 overflow-y-auto">
            {tasks.map(task => (
              <div 
                key={task.id}
                className="rounded border border-zinc-800 bg-zinc-800/40 p-2 hover:bg-zinc-800/60 transition-colors"
              >
                <p className="text-sm text-zinc-200 leading-snug">{task.title}</p>
                {task.due && (
                  <p className="text-xs text-zinc-500 mt-1">
                    Due: {new Date(task.due).toLocaleDateString()}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </aside>
  );
}
