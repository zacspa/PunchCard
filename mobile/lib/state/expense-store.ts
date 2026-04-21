import { create } from "zustand";
import type { Expense } from "../models/expense";
import { listExpenses } from "../db/expenses";
import { expenseQueueSize } from "../db/expense-queue";

type ExpenseState = {
  items: Expense[];
  pendingSync: number;
  loading: boolean;
  refresh: () => Promise<void>;
};

export const useExpenseStore = create<ExpenseState>((set) => ({
  items: [],
  pendingSync: 0,
  loading: false,
  refresh: async () => {
    set({ loading: true });
    const [items, pending] = await Promise.all([
      listExpenses(200),
      expenseQueueSize(),
    ]);
    set({ items, pendingSync: pending, loading: false });
  },
}));
