import { Pressable, StyleSheet, View } from "react-native";
import { Icon } from "react-native-paper";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { BottomTabBarProps } from "@react-navigation/bottom-tabs";

import { useTokens } from "@/lib/theme";
import { PCText } from "./PCText";

type TabDef = {
  name: string;
  label: string;
  icon: string;
};

const TABS: TabDef[] = [
  { name: "index", label: "Clock", icon: "clock-outline" },
  { name: "expenses/index", label: "Expenses", icon: "receipt-text-outline" },
  { name: "log", label: "Log", icon: "format-list-bulleted" },
];

export const PCTabBar = ({ state, navigation }: BottomTabBarProps) => {
  const t = useTokens();
  const insets = useSafeAreaInsets();

  return (
    <View
      style={[
        styles.bar,
        {
          backgroundColor: t.palette.cream100,
          borderTopColor: t.palette.cream200,
          paddingBottom: insets.bottom > 0 ? insets.bottom : 8,
          paddingLeft: insets.left + 10,
          paddingRight: insets.right + 10,
        },
      ]}
    >
      {TABS.map((tab) => {
        const routeIndex = state.routes.findIndex((r) => r.name === tab.name);
        if (routeIndex === -1) return null;
        const isActive = state.index === routeIndex;
        const iconColor = isActive ? t.palette.teal600 : t.palette.ink500;
        const labelColor = isActive ? t.palette.ink900 : t.palette.ink500;

        return (
          <Pressable
            key={tab.name}
            style={styles.item}
            onPress={() => {
              const event = navigation.emit({
                type: "tabPress",
                target: state.routes[routeIndex].key,
                canPreventDefault: true,
              });
              if (!isActive && !event.defaultPrevented) {
                navigation.navigate(state.routes[routeIndex].name, state.routes[routeIndex].params);
              }
            }}
            accessibilityRole="button"
            accessibilityState={isActive ? { selected: true } : {}}
            accessibilityLabel={tab.label}
          >
            <View
              style={[
                styles.pill,
                { backgroundColor: isActive ? t.palette.teal100 : "transparent" },
              ]}
            >
              <Icon source={tab.icon} size={22} color={iconColor} />
            </View>
            <PCText
              style={{
                fontFamily: isActive ? t.fonts.bodySemi : t.fonts.bodyMedium,
                fontSize: 11,
                color: labelColor,
                letterSpacing: 0.2,
                marginTop: 2,
              }}
            >
              {tab.label}
            </PCText>
          </Pressable>
        );
      })}
    </View>
  );
};

const styles = StyleSheet.create({
  bar: {
    flexDirection: "row",
    borderTopWidth: 1,
    paddingTop: 6,
  },
  item: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 6,
  },
  pill: {
    width: 48,
    height: 26,
    borderRadius: 13,
    alignItems: "center",
    justifyContent: "center",
  },
});
