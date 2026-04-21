import { Image, View } from "react-native";
import { Icon } from "react-native-paper";

import { useTokens } from "@/lib/theme";
import { formatAmount } from "@/lib/models/expense";
import type { Expense } from "@/lib/models/expense";
import { PCChip } from "./PCChip";
import { PCHairline } from "./PCHairline";
import { PCProjectDot } from "./PCProjectDot";
import { PCText } from "./PCText";

type Props = {
  expense: Expense;
  showDivider?: boolean;
};

export const PCExpenseRow = ({ expense, showDivider = true }: Props) => {
  const t = useTokens();
  const isPending = expense.syncState !== "synced";
  const description = expense.note?.trim() || expense.category || null;

  return (
    <View>
      <View style={{ flexDirection: "row", alignItems: "center", paddingVertical: 12, gap: 12 }}>
        <Thumbnail imagePath={expense.receiptImagePath} />
        <View style={{ flex: 1, minWidth: 0 }}>
          <PCText
            numberOfLines={1}
            style={{
              fontFamily: t.fonts.bodySemi,
              fontSize: 15,
              color: t.palette.ink900,
              marginBottom: 2,
            }}
          >
            {expense.merchant || "Untitled"}
          </PCText>
          {description ? (
            <PCText
              numberOfLines={1}
              style={{
                fontFamily: t.fonts.body,
                fontSize: 12,
                color: t.palette.ink500,
                marginBottom: 4,
              }}
            >
              {description}
            </PCText>
          ) : null}
          <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
            <PCProjectDot name={expense.project} size={8} />
            <PCText
              style={{
                fontFamily: t.fonts.mono,
                fontSize: 11,
                color: t.palette.ink700,
              }}
            >
              {expense.project}
            </PCText>
            {isPending ? (
              <PCChip label="pending" tone="mustard" style={{ marginLeft: 4 }} />
            ) : null}
          </View>
        </View>
        <PCText
          style={{
            fontFamily: t.fonts.monoSemi,
            fontSize: 16,
            color: t.palette.ink900,
          }}
        >
          {formatAmount(expense.amountCents, expense.currency)}
        </PCText>
      </View>
      {showDivider ? <PCHairline /> : null}
    </View>
  );
};

const Thumbnail = ({ imagePath }: { imagePath: string | null }) => {
  const t = useTokens();
  const size = { width: 44, height: 56, borderRadius: 8 };
  if (imagePath) {
    return (
      <Image
        source={{ uri: imagePath }}
        style={[size, { backgroundColor: t.palette.cream200 }]}
      />
    );
  }
  return (
    <View
      style={[
        size,
        {
          backgroundColor: t.palette.cream100,
          alignItems: "center",
          justifyContent: "center",
          borderWidth: 1,
          borderColor: t.palette.cream200,
        },
      ]}
    >
      <Icon source="receipt-text-outline" size={18} color={t.palette.ink500} />
    </View>
  );
};
