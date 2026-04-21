import { useEffect } from "react";
import { AppState, useColorScheme, View } from "react-native";
import { Stack } from "expo-router";
import { PaperProvider } from "react-native-paper";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import * as SplashScreen from "expo-splash-screen";
import {
  Fraunces_500Medium,
  Fraunces_600SemiBold,
  Fraunces_700Bold,
} from "@expo-google-fonts/fraunces";
import {
  Inter_400Regular,
  Inter_500Medium,
  Inter_600SemiBold,
  Inter_700Bold,
} from "@expo-google-fonts/inter";
import {
  JetBrainsMono_400Regular,
  JetBrainsMono_500Medium,
  JetBrainsMono_600SemiBold,
} from "@expo-google-fonts/jetbrains-mono";
import { useFonts } from "expo-font";

import { en, registerTranslation } from "react-native-paper-dates";

import "@/lib/db/client";
import "@/lib/sync/worker";
import { drainQueue } from "@/lib/sync/dispatcher";
import { registerSyncTask } from "@/lib/sync/worker";
import { migrateGlobalSyncToProjects } from "@/lib/config/secure";
import { useSessionStore } from "@/lib/state/session-store";
import { darkPaperTheme, lightPaperTheme } from "@/lib/theme";

registerTranslation("en", en);
SplashScreen.preventAutoHideAsync().catch(() => {});

export default function RootLayout() {
  const scheme = useColorScheme();
  const theme = scheme === "dark" ? darkPaperTheme : lightPaperTheme;
  const refresh = useSessionStore((s) => s.refresh);

  const [fontsLoaded] = useFonts({
    Fraunces_500Medium,
    Fraunces_600SemiBold,
    Fraunces_700Bold,
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
    Inter_700Bold,
    JetBrainsMono_400Regular,
    JetBrainsMono_500Medium,
    JetBrainsMono_600SemiBold,
  });

  useEffect(() => {
    SplashScreen.hideAsync().catch(() => {});
  }, []);

  useEffect(() => {
    migrateGlobalSyncToProjects().then(() => refresh()).catch(() => refresh());
    registerSyncTask();
    const sub = AppState.addEventListener("change", (state) => {
      if (state === "active") {
        refresh();
        drainQueue().then(() => refresh()).catch(() => {});
      }
    });
    return () => sub.remove();
  }, [refresh]);

  // Render immediately; unloaded fonts fall back to the system font. This
  // avoids the app being stuck on the splash while fonts download in Expo Go.
  void fontsLoaded;

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <PaperProvider theme={theme}>
          <View style={{ flex: 1, backgroundColor: theme.colors.background }}>
            <StatusBar style={scheme === "dark" ? "light" : "dark"} />
            <Stack
              screenOptions={{
                headerStyle: { backgroundColor: theme.colors.background },
                headerTitleStyle: { fontFamily: "Fraunces_600SemiBold", fontSize: 20 },
                headerTintColor: theme.colors.onBackground,
                headerShadowVisible: false,
                contentStyle: { backgroundColor: theme.colors.background },
              }}
            >
              <Stack.Screen name="index" options={{ title: "PunchCard", headerShown: false }} />
              <Stack.Screen
                name="punch-in"
                options={{ title: "Punch In", presentation: "modal" }}
              />
              <Stack.Screen
                name="punch-out"
                options={{ title: "Punch Out", presentation: "modal" }}
              />
              <Stack.Screen
                name="log-note"
                options={{ title: "Log Note", presentation: "modal" }}
              />
              <Stack.Screen name="settings/index" options={{ title: "Settings" }} />
              <Stack.Screen name="settings/projects" options={{ title: "Projects" }} />
              <Stack.Screen name="settings/project/[name]" options={{ title: "Project" }} />
              <Stack.Screen
                name="settings/share"
                options={{ title: "Share Config", presentation: "modal" }}
              />
              <Stack.Screen
                name="settings/scan"
                options={{ title: "Scan QR", presentation: "modal" }}
              />
            </Stack>
          </View>
        </PaperProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
