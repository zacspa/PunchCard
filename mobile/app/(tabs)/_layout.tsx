import { Tabs } from "expo-router";

import { PCTabBar } from "@/components/pc";

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{ headerShown: false }}
      tabBar={(props) => <PCTabBar {...props} />}
    >
      <Tabs.Screen name="index" options={{ title: "Clock" }} />
      <Tabs.Screen name="expenses/index" options={{ title: "Expenses" }} />
      <Tabs.Screen name="log" options={{ title: "Log" }} />
    </Tabs>
  );
}
