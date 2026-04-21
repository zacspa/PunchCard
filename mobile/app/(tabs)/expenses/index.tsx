import { ScrollView, StyleSheet, View } from "react-native";
import { Icon, IconButton } from "react-native-paper";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { PCCard, PCMark, PCText } from "@/components/pc";
import { useTokens } from "@/lib/theme";

export default function ExpensesList() {
  const t = useTokens();
  const insets = useSafeAreaInsets();

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
          gap: 12,
        }}
        showsVerticalScrollIndicator={false}
      >
        <EmptyState />
      </ScrollView>

      <View
        style={[
          styles.fabWrap,
          { right: 20 + insets.right, bottom: 20 },
        ]}
      >
        <IconButton
          icon="camera-outline"
          size={26}
          mode="contained"
          iconColor={t.palette.cream50}
          containerColor={t.palette.rust600}
          onPress={() => {
            /* capture flow ships in Slice 1 */
          }}
          style={styles.fab}
          accessibilityLabel="Snap receipt"
          disabled
        />
      </View>
    </View>
  );
}

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
          Snap a receipt to get started. Coming in the next release.
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
  fabWrap: {
    position: "absolute",
  },
  fab: {
    width: 60,
    height: 60,
    borderRadius: 30,
    margin: 0,
  },
});
