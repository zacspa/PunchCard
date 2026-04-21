import { asc, eq } from "drizzle-orm";
import { db } from "./client";
import { expenseSyncQueue } from "./schema";

export const enqueueExpense = async (
  expenseId: string,
  error?: string,
): Promise<void> => {
  await db
    .insert(expenseSyncQueue)
    .values({
      expenseId,
      enqueuedAt: new Date().toISOString(),
      lastError: error ?? null,
    })
    .onConflictDoUpdate({
      target: expenseSyncQueue.expenseId,
      set: { lastError: error ?? null, enqueuedAt: new Date().toISOString() },
    });
};

export const dequeueExpense = async (expenseId: string): Promise<void> => {
  await db.delete(expenseSyncQueue).where(eq(expenseSyncQueue.expenseId, expenseId));
};

export const listQueuedExpenses = async (): Promise<string[]> => {
  const rows = await db
    .select()
    .from(expenseSyncQueue)
    .orderBy(asc(expenseSyncQueue.enqueuedAt));
  return rows.map((r) => r.expenseId);
};

export const expenseQueueSize = async (): Promise<number> => {
  const rows = await db.select().from(expenseSyncQueue);
  return rows.length;
};
