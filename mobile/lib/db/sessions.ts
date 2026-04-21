import { and, desc, eq, isNull } from "drizzle-orm";
import { db } from "./client";
import { sessions } from "./schema";
import type { Session } from "../models/session";

const rowToSession = (row: typeof sessions.$inferSelect): Session => ({
  id: row.id,
  project: row.project,
  startTime: row.startTime,
  endTime: row.endTime,
  notes: row.notes ?? [],
  summary: row.summary,
  commits: row.commits ?? [],
  deleted: row.deleted,
});

export const getActiveSession = async (): Promise<Session | null> => {
  const rows = await db
    .select()
    .from(sessions)
    .where(and(isNull(sessions.endTime), eq(sessions.deleted, false)))
    .limit(1);
  return rows.length ? rowToSession(rows[0]) : null;
};

export const getSessionById = async (id: string): Promise<Session | null> => {
  const rows = await db.select().from(sessions).where(eq(sessions.id, id)).limit(1);
  return rows.length ? rowToSession(rows[0]) : null;
};

export const insertSession = async (s: Session): Promise<void> => {
  await db.insert(sessions).values({
    id: s.id,
    project: s.project,
    startTime: s.startTime,
    endTime: s.endTime,
    notes: s.notes,
    summary: s.summary,
    commits: s.commits,
    deleted: s.deleted,
  });
};

export const updateSession = async (s: Session): Promise<void> => {
  await db
    .update(sessions)
    .set({
      project: s.project,
      startTime: s.startTime,
      endTime: s.endTime,
      notes: s.notes,
      summary: s.summary,
      commits: s.commits,
      deleted: s.deleted,
    })
    .where(eq(sessions.id, s.id));
};

export const appendNote = async (id: string, note: string): Promise<Session | null> => {
  const current = await getSessionById(id);
  if (!current) return null;
  const updated: Session = { ...current, notes: [...current.notes, note] };
  await updateSession(updated);
  return updated;
};

export const closeSession = async (
  id: string,
  endTime: string,
  summary: string | null,
): Promise<Session | null> => {
  const current = await getSessionById(id);
  if (!current) return null;
  const updated: Session = { ...current, endTime, summary };
  await updateSession(updated);
  return updated;
};

export const listSessions = async (limit = 50): Promise<Session[]> => {
  const rows = await db
    .select()
    .from(sessions)
    .where(eq(sessions.deleted, false))
    .orderBy(desc(sessions.startTime))
    .limit(limit);
  return rows.map(rowToSession);
};
