import { useCallback, useMemo } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useFocusEffect, useRouter } from "expo-router";
import { Icon, IconButton } from "react-native-paper";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { format, isToday, isYesterday, startOfMonth } from "date-fns";

import {
  PCCard,
  PCChip,
  PCExpenseRow,
  PCMark,
  PCText,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { formatAmount } from "@/lib/models/expense";
import type { Expense } from "@/lib/models/expense";
import { useExpenseStore } from "@/lib/state/expense-store";

type DayGroup = { key: string; label: string; items: Expense[] };

const groupByDay = (items: Expense[]): DayGroup[] => {
  const groups = new Map<string, Expense[]>();
  for (const e of items) {
    const d = new Date(e.capturedAt);
    const key = format(d, "yyyy-MM-dd");
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(e);
  }
  return Array.from(groups.entries()).map(([key, items]) => {
    const d = new Date(items[0].capturedAt);
    const label = isToday(d)
      ? `Today · ${format(d, "MMM d")}`
      : isYesterday(d)
        ? `Yesterday · ${format(d, "MMM d")}`
        : format(d, "EEE, MMM d");
    return { key, label, items };
  });
};

export default function ExpensesList() {
  const router = useRouter();
  const t = useTokens();
  const insets = useSafeAreaInsets();
  const { items, pendingSync, refresh } = useExpenseStore();

  useFocusEffect(
    useCallback(() => {
      refresh();
    }, [refresh]),
  );

  const monthStats = useMemo(() => {
    const monthStart = startOfMonth(new Date());
    const inMonth = items.filter(
      (e) => new Date(e.capturedAt).getTime() >= monthStart.getTime(),
    );
    const totalCents = inMonth.reduce((sum, e) => sum + e.amountCents, 0);
    return { count: inMonth.length, totalCents, items: inMonth };
  }, [items]);

  const groups = useMemo(() => groupByDay(items), [items]);

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <View
        style={[
          styles.appbar,
          {
            marginTop: insets.top,
            paddingLeft: 20 + insets.left,
            paddingRight: 20 + insets.right,
          },
        ]}
      >
        <PCMark size={22} />
        <PCText
          style={{
            fontFamily: t.fonts.display,
            fontSize: 20,
            color: t.palette.ink900,
          }}
        >
          Expenses
        </PCText>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView
        contentContainerStyle={{
          paddingLeft: 20 + insets.left,
          paddingRight: 20 + insets.right,
          paddingBottom: 96,
          gap: 16,
        }}
        showsVerticalScrollIndicator={false}
      >
        <MonthHero
          count={monthStats.count}
          totalCents={monthStats.totalCents}
          pendingCount={pendingSync}
        />

        {items.length === 0 ? (
          <EmptyState />
        ) : (
          groups.map((g) => (
            <View key={g.key}>
              <PCText
                variant="overline"
                tone="tertiary"
                style={{ marginBottom: 8 }}
              >
                {g.label}
              </PCText>
              <PCCard padding={0}>
                <View style={{ paddingHorizontal: 16 }}>
                  {g.items.map((e, i, arr) => (
                    <PCExpenseRow
                      key={e.id}
                      expense={e}
                      showDivider={i < arr.length - 1}
                      onPress={() =>
                        router.push({ pathname: "/expense-new", params: { id: e.id } })
                      }
                    />
                  ))}
                </View>
              </PCCard>
            </View>
          ))
        )}
      </ScrollView>

      <View style={[styles.fabWrap, { right: 20 + insets.right, bottom: 20 }]}>
        <IconButton
          icon="camera-outline"
          size={26}
          mode="contained"
          iconColor={t.palette.cream50}
          containerColor={t.palette.rust600}
          onPress={() => router.push("/expense-capture")}
          style={styles.fab}
          accessibilityLabel="Snap receipt"
        />
      </View>
    </View>
  );
}

const MonthHero = ({
  count,
  totalCents,
  pendingCount,
}: {
  count: number;
  totalCents: number;
  pendingCount: number;
}) => {
  const t = useTokens();
  const monthLabel = format(new Date(), "MMMM").toLowerCase();

  return (
    <PCCard padding={20}>
      <View style={{ flexDirection: "row", justifyContent: "space-between" }}>
        <PCText variant="overline" tone="tertiary">
          {monthLabel} · month to date
        </PCText>
        <PCText
          style={{
            fontFamily: t.fonts.mono,
            fontSize: 12,
            color: t.palette.ink500,
          }}
        >
          {count} {count === 1 ? "item" : "items"}
        </PCText>
      </View>
      <View style={{ flexDirection: "row", alignItems: "baseline", marginTop: 8 }}>
        <PCText
          style={{
            fontFamily: t.fonts.display,
            fontSize: 40,
            lineHeight: 46,
            color: t.palette.ink900,
          }}
        >
          {formatAmount(totalCents, "USD")}
        </PCText>
      </View>
      {pendingCount > 0 ? (
        <View style={{ flexDirection: "row", marginTop: 10 }}>
          <PCChip
            label={`${pendingCount} pending`}
            tone="mustard"
            leading={<Icon source="cloud-upload-outline" size={14} color={t.palette.mustard600} />}
          />
        </View>
      ) : null}
    </PCCard>
  );
};

const EmptyState = () => {
  const t = useTokens();
  return (
    <PCCard padding={28}>
      <View style={{ alignItems: "center", gap: 10 }}>
        <View
          style={{
            width: 52,
            height: 52,
            borderRadius: 26,
            backgroundColor: t.palette.cream100,
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Icon source="receipt-text-outline" size={26} color={t.palette.ink500} />
        </View>
        <PCText
          style={{
            fontFamily: t.fonts.display,
            fontSize: 20,
            color: t.palette.ink900,
            textAlign: "center",
          }}
        >
          No expenses yet
        </PCText>
        <PCText
          variant="supporting"
          tone="secondary"
          style={{ textAlign: "center" }}
        >
          Tap the camera to snap your first receipt.
        </PCText>
      </View>
    </PCCard>
  );
};

const styles = StyleSheet.create({
  appbar: {
    height: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  fabWrap: { position: "absolute" },
  fab: { width: 60, height: 60, borderRadius: 30, margin: 0 },
});
