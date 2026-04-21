export const parseDurationMinutes = (input: string): number | null => {
  const s = input.trim().toLowerCase();
  if (!s) return null;
  const bare = /^(\d+)$/.exec(s);
  if (bare) return parseInt(bare[1], 10);
  const full = /^(?:(\d+)h)?\s*(?:(\d+)m)?$/.exec(s);
  if (!full) return null;
  const [, h, m] = full;
  if (!h && !m) return null;
  return (h ? parseInt(h, 10) * 60 : 0) + (m ? parseInt(m, 10) : 0);
};

export const parseAtTime = (input: string, now: Date = new Date()): Date | null => {
  const s = input.trim().toLowerCase();
  if (!s) return null;
  const m = /^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/.exec(s);
  if (!m) return null;
  let hour = parseInt(m[1], 10);
  const minute = m[2] ? parseInt(m[2], 10) : 0;
  const suffix = m[3];
  if (hour > 23 || minute > 59) return null;
  if (suffix === "am") {
    if (hour === 12) hour = 0;
  } else if (suffix === "pm") {
    if (hour !== 12) hour += 12;
  }
  const d = new Date(now);
  d.setHours(hour, minute, 0, 0);
  if (d.getTime() > now.getTime()) return null;
  return d;
};

export const minutesAgo = (minutes: number, now: Date = new Date()): Date =>
  new Date(now.getTime() - minutes * 60_000);
