import * as BackgroundTask from "expo-background-task";
import * as TaskManager from "expo-task-manager";

import { drainQueue } from "./dispatcher";
import { drainExpenseQueue } from "./expense-dispatcher";

export const SYNC_TASK_NAME = "punchcard.sync.drain";

if (!TaskManager.isTaskDefined(SYNC_TASK_NAME)) {
  TaskManager.defineTask(SYNC_TASK_NAME, async () => {
    try {
      await Promise.all([drainQueue(), drainExpenseQueue()]);
      return BackgroundTask.BackgroundTaskResult.Success;
    } catch {
      return BackgroundTask.BackgroundTaskResult.Failed;
    }
  });
}

export const registerSyncTask = async (): Promise<void> => {
  try {
    const status = await BackgroundTask.getStatusAsync();
    if (status === BackgroundTask.BackgroundTaskStatus.Restricted) return;
    const registered = await TaskManager.isTaskRegisteredAsync(SYNC_TASK_NAME);
    if (registered) return;
    await BackgroundTask.registerTaskAsync(SYNC_TASK_NAME, {
      minimumInterval: 15,
    });
  } catch {}
};
