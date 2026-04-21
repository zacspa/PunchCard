import { asc, eq } from "drizzle-orm";
import { db } from "./client";
import { syncQueue } from "./schema";

export const enqueue = async (sessionId: string, error?: string): Promise<void> => {
  await db
    .insert(syncQueue)
    .values({
      sessionId,
      enqueuedAt: new Date().toISOString(),
      lastError: error ?? null,
    })
    .onConflictDoUpdate({
      target: syncQueue.sessionId,
      set: { lastError: error ?? null, enqueuedAt: new Date().toISOString() },
    });
};

export const dequeue = async (sessionId: string): Promise<void> => {
  await db.delete(syncQueue).where(eq(syncQueue.sessionId, sessionId));
};

export const listQueued = async (): Promise<string[]> => {
  const rows = await db.select().from(syncQueue).orderBy(asc(syncQueue.enqueuedAt));
  return rows.map((r) => r.sessionId);
};

export const queueSize = async (): Promise<number> => {
  const rows = await db.select().from(syncQueue);
  return rows.length;
};
