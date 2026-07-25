import { useState, useEffect } from 'react';
import { GoogleTask, TaskCache } from '../types/tasks';
import * as tasksService from '../services/tasks';

const CACHE_KEY = 'chronolog-tasks-cache';
const CACHE_TTL = 15 * 60 * 1000; // 15 minutes

interface UseTasksOptions {
  selectedListId: string | null;
  enabled?: boolean;
}

interface UseTasksReturn {
  tasks: GoogleTask[];
  loading: boolean;
  error: string;
  refetch: () => Promise<void>;
}

/**
 * Check if cache is valid
 * Invalid if:
 * 1. Cache doesn't exist
 * 2. TTL expired (older than 15 minutes)
 * 3. listId mismatch (user switched lists)
 */
function isCacheValid(cache: TaskCache | null, currentListId: string | null): boolean {
  if (!cache || !currentListId) return false;
  
  // Check list ID match
  if (cache.listId !== currentListId) {
    console.log('Cache invalidated: list ID mismatch');
    return false;
  }
  
  // Check TTL
  const age = Date.now() - cache.timestamp;
  if (age > CACHE_TTL) {
    console.log('Cache invalidated: TTL expired');
    return false;
  }
  
  return true;
}

/**
 * Load from cache only if valid
 */
function loadFromCache(currentListId: string | null): GoogleTask[] | null {
  try {
    const cached = localStorage.getItem(CACHE_KEY);
    if (!cached) return null;
    
    const data: TaskCache = JSON.parse(cached);
    
    if (!isCacheValid(data, currentListId)) {
      localStorage.removeItem(CACHE_KEY);
      return null;
    }
    
    return data.tasks;
  } catch (err) {
    console.warn('Failed to load cache:', err);
    localStorage.removeItem(CACHE_KEY);
    return null;
  }
}

/**
 * Save to cache with list ID
 */
function saveToCache(tasks: GoogleTask[], listId: string) {
  try {
    const cache: TaskCache = {
      tasks,
      listId,
      timestamp: Date.now()
    };
    localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
  } catch (err) {
    console.warn('Failed to save cache:', err);
  }
}

export function useTasks({ selectedListId, enabled = true }: UseTasksOptions): UseTasksReturn {
  const [tasks, setTasks] = useState<GoogleTask[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const fetchTasks = async () => {
    if (!selectedListId) {
      setTasks([]);
      return;
    }

    setLoading(true);
    setError('');
    
    try {
      const data = await tasksService.getTasks();
      setTasks(data);
      saveToCache(data, selectedListId);
    } catch (err) {
      setError('Could not load tasks.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!enabled) return;
    
    // Try cache first
    const cached = loadFromCache(selectedListId);
    if (cached) {
      setTasks(cached);
      return;
    }
    
    // Cache miss: fetch from API
    fetchTasks();
  }, [selectedListId, enabled]);

  return {
    tasks,
    loading,
    error,
    refetch: fetchTasks
  };
}

/**
 * Clear task cache (call when user changes list selection)
 */
export function clearTaskCache() {
  localStorage.removeItem(CACHE_KEY);
}
