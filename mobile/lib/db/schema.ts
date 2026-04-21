import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import type { ExpenseOCR, ExpenseSyncState } from "../models/expense";

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

export const expenses = sqliteTable("expenses", {
  id: text("id").primaryKey(),
  project: text("project").notNull(),
  merchant: text("merchant").notNull().default(""),
  amountCents: integer("amount_cents").notNull().default(0),
  currency: text("currency").notNull().default("USD"),
  capturedAt: text("captured_at").notNull(),
  category: text("category"),
  billable: integer("billable", { mode: "boolean" }).notNull().default(true),
  note: text("note"),
  receiptImagePath: text("receipt_image_path"),
  ocr: text("ocr", { mode: "json" }).$type<ExpenseOCR | null>(),
  syncState: text("sync_state").$type<ExpenseSyncState>().notNull().default("local"),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
  deleted: integer("deleted", { mode: "boolean" }).notNull().default(false),
});

export const expenseSyncQueue = sqliteTable("expense_sync_queue", {
  expenseId: text("expense_id").primaryKey(),
  enqueuedAt: text("enqueued_at").notNull(),
  lastError: text("last_error"),
});

export type SessionRow = typeof sessions.$inferSelect;
export type SessionInsert = typeof sessions.$inferInsert;
export type ExpenseRow = typeof expenses.$inferSelect;
export type ExpenseInsert = typeof expenses.$inferInsert;
