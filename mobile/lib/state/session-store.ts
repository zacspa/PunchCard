import { create } from "zustand";
import type { Session } from "../models/session";
import { getActiveSession, listSessions } from "../db/sessions";
import { queueSize } from "../db/sync-queue";
import {
  getLastEndedSession,
  getTodayHours,
  getWeekStats,
  type WeekStats,
} from "../db/stats";

type SessionState = {
  active: Session | null;
  pendingSync: number;
  recents: Session[];
  todayHours: number;
  week: WeekStats | null;
  lastEnded: Session | null;
  refresh: () => Promise<void>;
  setActive: (s: Session | null) => void;
};

export const useSessionStore = create<SessionState>((set) => ({
  active: null,
  pendingSync: 0,
  recents: [],
  todayHours: 0,
  week: null,
  lastEnded: null,
  refresh: async () => {
    const now = new Date();
    const [active, pending, recents, todayHours, week, lastEnded] = await Promise.all([
      getActiveSession(),
      queueSize(),
      listSessions(8),
      getTodayHours(now),
      getWeekStats(now),
      getLastEndedSession(),
    ]);
    set({ active, pendingSync: pending, recents, todayHours, week, lastEnded });
  },
  setActive: (s) => set({ active: s }),
}));
