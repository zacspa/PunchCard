import { and, desc, eq, gte } from "drizzle-orm";
import { db } from "./client";
import { expenses } from "./schema";
import type { Expense } from "../models/expense";

const rowToExpense = (row: typeof expenses.$inferSelect): Expense => ({
  id: row.id,
  project: row.project,
  merchant: row.merchant,
  amountCents: row.amountCents,
  currency: row.currency,
  capturedAt: row.capturedAt,
  category: row.category,
  billable: row.billable,
  note: row.note,
  receiptImagePath: row.receiptImagePath,
  ocr: row.ocr ?? null,
  syncState: row.syncState,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  deleted: row.deleted,
});

export const insertExpense = async (e: Expense): Promise<void> => {
  await db.insert(expenses).values({
    id: e.id,
    project: e.project,
    merchant: e.merchant,
    amountCents: e.amountCents,
    currency: e.currency,
    capturedAt: e.capturedAt,
    category: e.category,
    billable: e.billable,
    note: e.note,
    receiptImagePath: e.receiptImagePath,
    ocr: e.ocr,
    syncState: e.syncState,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    deleted: e.deleted,
  });
};

export const updateExpense = async (e: Expense): Promise<void> => {
  await db
    .update(expenses)
    .set({
      project: e.project,
      merchant: e.merchant,
      amountCents: e.amountCents,
      currency: e.currency,
      capturedAt: e.capturedAt,
      category: e.category,
      billable: e.billable,
      note: e.note,
      receiptImagePath: e.receiptImagePath,
      ocr: e.ocr,
      syncState: e.syncState,
      updatedAt: e.updatedAt,
      deleted: e.deleted,
    })
    .where(eq(expenses.id, e.id));
};

export const getExpenseById = async (id: string): Promise<Expense | null> => {
  const rows = await db.select().from(expenses).where(eq(expenses.id, id)).limit(1);
  return rows.length ? rowToExpense(rows[0]) : null;
};

export const listExpenses = async (limit = 100): Promise<Expense[]> => {
  const rows = await db
    .select()
    .from(expenses)
    .where(eq(expenses.deleted, false))
    .orderBy(desc(expenses.capturedAt))
    .limit(limit);
  return rows.map(rowToExpense);
};

export const listExpensesSince = async (sinceISO: string): Promise<Expense[]> => {
  const rows = await db
    .select()
    .from(expenses)
    .where(and(eq(expenses.deleted, false), gte(expenses.capturedAt, sinceISO)))
    .orderBy(desc(expenses.capturedAt));
  return rows.map(rowToExpense);
};
