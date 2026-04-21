import { useCallback } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useFocusEffect } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { PCCard, PCMark, PCSessionRow, PCText } from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { useSessionStore } from "@/lib/state/session-store";

export default function LogTab() {
  const t = useTokens();
  const insets = useSafeAreaInsets();
  const { recents, refresh } = useSessionStore();

  useFocusEffect(
    useCallback(() => {
      refresh();
    }, [refresh]),
  );

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
          Log
        </PCText>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView
        contentContainerStyle={{
          paddingLeft: 20 + insets.left,
          paddingRight: 20 + insets.right,
          paddingBottom: 24,
          gap: 12,
        }}
        showsVerticalScrollIndicator={false}
      >
        {recents.length === 0 ? (
          <PCCard padding={24}>
            <PCText
              variant="supporting"
              tone="secondary"
              style={{ textAlign: "center" }}
            >
              Sessions will appear here after you punch in and out.
            </PCText>
          </PCCard>
        ) : (
          <View>
            <View style={styles.sectionHead}>
              <PCText variant="overline" tone="tertiary">
                Recent sessions
              </PCText>
              <PCText variant="supporting" tone="accent">
                {recents.length}
              </PCText>
            </View>
            <PCCard padding={0}>
              <View style={{ paddingHorizontal: 16 }}>
                {recents.map((s, i, arr) => (
                  <PCSessionRow
                    key={s.id}
                    session={s}
                    showDivider={i < arr.length - 1}
                  />
                ))}
              </View>
            </PCCard>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  appbar: {
    height: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  sectionHead: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
});
