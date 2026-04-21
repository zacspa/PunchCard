import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const sessions = sqliteTable("sessions", {
  id: text("id").primaryKey(),
  project: text("project").notNull(),
  startTime: text("start_time").notNull(),
  endTime: text("end_time"),
  notes: text("notes", { mode: "json" }).$type<string[]>().notNull().default([]),
  summary: text("summary"),
  commits: text("commits", { mode: "json" }).$type<string[]>().notNull().default([]),
  deleted: integer("deleted", { mode: "boolean" }).notNull().default(false),
  deletedAt: text("deleted_at"),
});

export const projects = sqliteTable("projects", {
  name: text("name").primaryKey(),
  webhookURL: text("webhook_url"),
  syncEnabled: integer("sync_enabled", { mode: "boolean" }).notNull().default(false),
});

export const syncQueue = sqliteTable("sync_queue", {
  sessionId: text("session_id").primaryKey(),
  enqueuedAt: text("enqueued_at").notNull(),
  lastError: text("last_error"),
});

export type SessionRow = typeof sessions.$inferSelect;
export type SessionInsert = typeof sessions.$inferInsert;
