import { useEffect, useState } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import { Snackbar, TextInput } from "react-native-paper";

import {
  PCButton,
  PCCard,
  PCChip,
  PCStampCard,
  PCText,
  PCTimer,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { closeSession, getActiveSession } from "@/lib/db/sessions";
import { useSessionStore } from "@/lib/state/session-store";
import { pushBestEffort } from "@/lib/sync/dispatcher";
import { hoursBetween } from "@/lib/models/session";
import type { Session } from "@/lib/models/session";

export default function PunchOutScreen() {
  const router = useRouter();
  const t = useTokens();
  const refresh = useSessionStore((s) => s.refresh);

  const [active, setActive] = useState<Session | null>(null);
  const [summary, setSummary] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [nowTick, setNowTick] = useState(() => new Date());

  useEffect(() => {
    getActiveSession().then((s) => {
      if (!s) setError("No active session to stop.");
      setActive(s);
    });
    const id = setInterval(() => setNowTick(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const submit = async () => {
    if (!active) return;
    const now = Date.now();
    const startMs = new Date(active.startTime).getTime();
    if (now <= startMs) {
      setError("Clock looks off — can't end before the session started. Check your phone's time.");
      return;
    }
    setSubmitting(true);
    const endTime = new Date(now).toISOString();
    const summaryTrimmed = summary.trim() || null;
    const updated = await closeSession(active.id, endTime, summaryTrimmed);
    if (updated) pushBestEffort(updated);
    await refresh();
    setSubmitting(false);
    router.back();
  };

  const hours = active ? hoursBetween(active.startTime, nowTick.toISOString()) : null;

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        {active ? (
          <>
            <PCCard tone="teal" padding={20}>
              <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
                <PCText variant="overline" style={{ color: t.palette.teal600 }}>
                  Current
                </PCText>
                <PCChip label="LIVE" tone="live" />
              </View>
              <PCText
                style={{
                  fontFamily: t.fonts.monoSemi,
                  fontSize: 16,
                  color: t.palette.ink900,
                  marginTop: 4,
                  marginBottom: 12,
                }}
              >
                {active.project}
              </PCText>
              <PCTimer startedAt={active.startTime} size="md" />
            </PCCard>

            <View style={{ marginTop: 20 }}>
              <PCText variant="overline" tone="tertiary" style={{ marginBottom: 10 }}>
                Will stamp
              </PCText>
              <PCStampCard
                action="out"
                time={nowTick}
                project={active.project}
                hours={hours}
                inTime={new Date(active.startTime)}
                showPunchEdge
              />
            </View>

            <View style={{ marginTop: 20 }}>
              <PCText variant="overline" tone="tertiary" style={{ marginBottom: 10 }}>
                Summary
              </PCText>
              <TextInput
                mode="outlined"
                placeholder="What did you ship?"
                value={summary}
                onChangeText={setSummary}
                multiline
                numberOfLines={5}
                style={{ backgroundColor: t.palette.cream50 }}
              />
            </View>

            <View style={{ marginTop: 28, gap: 10 }}>
              <PCButton
                label="Punch Out"
                variant="rust"
                size="xl"
                fullWidth
                loading={submitting}
                onPress={submit}
              />
              <PCButton
                label="Cancel"
                variant="ghost"
                size="md"
                fullWidth
                onPress={() => router.back()}
              />
            </View>
          </>
        ) : (
          <PCCard tone="outline" padding={20}>
            <PCText variant="body">No active session.</PCText>
          </PCCard>
        )}
      </ScrollView>
      <Snackbar visible={error !== null} onDismiss={() => setError(null)} duration={4000}>
        {error ?? ""}
      </Snackbar>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
});
