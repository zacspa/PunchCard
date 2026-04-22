import { File } from "expo-file-system";
import type { Expense } from "../models/expense";

type ExpensePayload = {
  id: string;
  project: string;
  merchant: string;
  amountCents: number;
  currency: string;
  capturedAt: string;
  category: string | null;
  billable: boolean;
  note: string | null;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
  receiptImageBase64?: string;
  receiptImageName?: string;
};

export type ExpenseEnvelope = {
  action: "upsert-expenses";
  expenses: ExpensePayload[];
};

const readImageBase64 = (path: string): { base64: string; name: string } | null => {
  try {
    const file = new File(path);
    if (!file.exists) return null;
    return {
      base64: file.base64Sync(),
      name: file.name,
    };
  } catch {
    return null;
  }
};

export const buildExpenseEnvelope = (expenses: Expense[]): ExpenseEnvelope => ({
  action: "upsert-expenses",
  expenses: expenses.map(makeExpensePayload),
});

const makeExpensePayload = (e: Expense): ExpensePayload => {
  const payload: ExpensePayload = {
    id: e.id,
    project: e.project,
    merchant: e.merchant,
    amountCents: e.amountCents,
    currency: e.currency,
    capturedAt: e.capturedAt,
    category: e.category,
    billable: e.billable,
    note: e.note,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
    deleted: e.deleted,
  };
  if (e.receiptImagePath) {
    const image = readImageBase64(e.receiptImagePath);
    if (image) {
      payload.receiptImageBase64 = image.base64;
      payload.receiptImageName = image.name;
    }
  }
  return payload;
};
