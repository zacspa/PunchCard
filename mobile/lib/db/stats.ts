import { and, desc, eq, gte, isNotNull, lt } from "drizzle-orm";
import {
  endOfDay,
  endOfWeek,
  startOfDay,
  startOfWeek,
  differenceInMinutes,
  max,
  min,
} from "date-fns";

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

export const getSessionsBetween = async (from: Date, to: Date): Promise<Session[]> => {
  const rows = await db
    .select()
    .from(sessions)
    .where(
      and(
        eq(sessions.deleted, false),
        gte(sessions.startTime, from.toISOString()),
        lt(sessions.startTime, to.toISOString()),
      ),
    )
    .orderBy(desc(sessions.startTime));
  return rows.map(rowToSession);
};

const minutesOverlap = (sessionStart: Date, sessionEnd: Date, rangeStart: Date, rangeEnd: Date): number => {
  const a = max([sessionStart, rangeStart]);
  const b = min([sessionEnd, rangeEnd]);
  const diff = differenceInMinutes(b, a);
  return Math.max(0, diff);
};

const minutesForSessionInRange = (session: Session, rangeStart: Date, rangeEnd: Date, now: Date): number => {
  const start = new Date(session.startTime);
  const end = session.endTime ? new Date(session.endTime) : now;
  return minutesOverlap(start, end, rangeStart, rangeEnd);
};

export type WeekStats = {
  totalHours: number;
  byDayMinutes: number[];
  punchedDays: number;
  weekStart: Date;
  weekEnd: Date;
  todayIndex: number;
};

export const getWeekStats = async (now: Date = new Date()): Promise<WeekStats> => {
  const weekStart = startOfWeek(now, { weekStartsOn: 1 });
  const weekEnd = endOfWeek(now, { weekStartsOn: 1 });
  const list = await getSessionsBetween(weekStart, weekEnd);

  const byDay = new Array(7).fill(0) as number[];
  for (const s of list) {
    for (let i = 0; i < 7; i++) {
      const dayStart = new Date(weekStart);
      dayStart.setDate(weekStart.getDate() + i);
      const dayEnd = endOfDay(dayStart);
      byDay[i] += minutesForSessionInRange(s, startOfDay(dayStart), dayEnd, now);
    }
  }

  const totalMinutes = byDay.reduce((a, b) => a + b, 0);
  const punchedDays = byDay.filter((m) => m > 0).length;
  const todayIndex = Math.floor((now.getTime() - weekStart.getTime()) / 86_400_000);

  return {
    totalHours: Math.round((totalMinutes / 60) * 10) / 10,
    byDayMinutes: byDay,
    punchedDays,
    weekStart,
    weekEnd,
    todayIndex: Math.min(6, Math.max(0, todayIndex)),
  };
};

export const getTodayHours = async (now: Date = new Date()): Promise<number> => {
  const dayStart = startOfDay(now);
  const dayEnd = endOfDay(now);
  const list = await getSessionsBetween(dayStart, dayEnd);
  const minutes = list.reduce(
    (sum, s) => sum + minutesForSessionInRange(s, dayStart, dayEnd, now),
    0,
  );
  return Math.round((minutes / 60) * 10) / 10;
};

export const getLastEndedSession = async (): Promise<Session | null> => {
  const rows = await db
    .select()
    .from(sessions)
    .where(and(isNotNull(sessions.endTime), eq(sessions.deleted, false)))
    .orderBy(desc(sessions.endTime))
    .limit(1);
  return rows.length ? rowToSession(rows[0]) : null;
};
