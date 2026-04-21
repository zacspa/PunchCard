export type Session = {
  id: string;
  project: string;
  startTime: string;
  endTime: string | null;
  notes: string[];
  summary: string | null;
  commits: string[];
  deleted: boolean;
};

export type Project = { name: string };

export type SyncConfig = {
  webhookURL: string | null;
  sharedSecret: string | null;
  enabled: boolean;
};

export const hoursBetween = (startISO: string, endISO: string): number => {
  const ms = new Date(endISO).getTime() - new Date(startISO).getTime();
  return Math.round((ms / 3_600_000) * 100) / 100;
};
