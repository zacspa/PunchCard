import { getProjectSyncConfig } from "../config/project-sync";
import { getExpenseById, updateExpense } from "../db/expenses";
import { dequeueExpense, enqueueExpense, listQueuedExpenses } from "../db/expense-queue";
import type { Expense } from "../models/expense";
import { buildExpenseEnvelope } from "./expense-payload";
import { EXPENSE_TIMEOUT_MS, postEnvelope, type SyncResult } from "./client";

export const pushExpense = async (expense: Expense): Promise<SyncResult> => {
  const config = await getProjectSyncConfig(expense.project);
  if (!config || !config.enabled || !config.webhookURL) {
    await enqueueExpense(expense.id, `no sync for project '${expense.project}'`);
    return {
      ok: false,
      kind: !config?.enabled ? "disabled" : "not-configured",
      message: `Sync isn't configured for project '${expense.project}'.`,
    };
  }
  const result = await postEnvelope(
    {
      webhookURL: config.webhookURL,
      sharedSecret: config.sharedSecret,
      enabled: true,
    },
    buildExpenseEnvelope([expense]),
    EXPENSE_TIMEOUT_MS,
  );
  if (result.ok) {
    await dequeueExpense(expense.id);
    const synced: Expense = {
      ...expense,
      syncState: "synced",
      updatedAt: new Date().toISOString(),
    };
    await updateExpense(synced);
  } else {
    await enqueueExpense(expense.id, result.message);
  }
  return result;
};

export const pushExpenseBestEffort = (expense: Expense): void => {
  pushExpense(expense).catch(() => {});
};

let activeDrain: Promise<{ drained: number; remaining: number }> | null = null;

export const drainExpenseQueue = async (): Promise<{ drained: number; remaining: number }> => {
  if (activeDrain) return activeDrain;
  activeDrain = (async () => {
    try {
      const ids = await listQueuedExpenses();
      let drained = 0;
      for (const id of ids) {
        const e = await getExpenseById(id);
        if (!e) {
          await dequeueExpense(id);
          continue;
        }
        const r = await pushExpense(e);
        if (r.ok) drained++;
      }
      return { drained, remaining: (await listQueuedExpenses()).length };
    } finally {
      activeDrain = null;
    }
  })();
  return activeDrain;
};
