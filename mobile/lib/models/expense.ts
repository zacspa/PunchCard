export type ExpenseCategory = "meals" | "travel" | "software" | "supplies" | string;
export type ExpenseSyncState = "local" | "queued" | "synced" | "error";

export type ExpenseOCR = {
  rawText: string | null;
  parsed: {
    merchant?: string;
    amountCents?: number;
    currency?: string;
    capturedAt?: string;
  };
  confidence: number;
};

export type Expense = {
  id: string;
  project: string;
  merchant: string;
  amountCents: number;
  currency: string;
  capturedAt: string;
  category: ExpenseCategory | null;
  billable: boolean;
  note: string | null;
  receiptImagePath: string | null;
  ocr: ExpenseOCR | null;
  syncState: ExpenseSyncState;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
};

export const formatAmount = (cents: number, currency: string): string => {
  const whole = Math.floor(Math.abs(cents) / 100);
  const frac = Math.abs(cents) % 100;
  const sign = cents < 0 ? "-" : "";
  const symbol = currency === "USD" ? "$" : `${currency} `;
  return `${sign}${symbol}${whole}.${frac.toString().padStart(2, "0")}`;
};
