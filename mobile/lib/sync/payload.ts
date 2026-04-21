import type { Session } from "../models/session";
import { hoursBetween } from "../models/session";

type SessionPayload = {
  id: string;
  project: string;
  startTime: string;
  notes: string[];
  commits: string[];
  deleted: boolean;
  endTime?: string;
  hours?: number;
  summary?: string;
};

export type SyncEnvelope = {
  action: "upsert" | "replace";
  sessions: SessionPayload[];
};

const makeSessionPayload = (s: Session): SessionPayload => {
  const p: SessionPayload = {
    id: s.id,
    project: s.project,
    startTime: s.startTime,
    notes: s.notes,
    commits: s.commits,
    deleted: s.deleted,
  };
  if (s.endTime) {
    p.endTime = s.endTime;
    p.hours = hoursBetween(s.startTime, s.endTime);
  }
  if (s.summary) p.summary = s.summary;
  return p;
};

export const buildUpsertEnvelope = (sessions: Session[]): SyncEnvelope => ({
  action: "upsert",
  sessions: sessions.map(makeSessionPayload),
});
