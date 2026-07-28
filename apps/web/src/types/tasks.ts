export interface GoogleTask {
  id: string;
  title: string;
  notes?: string;
  due?: string;
  status?: string;
  taskListName?: string;
}

export interface GoogleTaskList {
  id: string;
  title: string;
}

export interface TaskCache {
  tasks: GoogleTask[];
  listId: string;
  timestamp: number;
}
