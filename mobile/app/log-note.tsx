import { useEffect, useState } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import { Snackbar, TextInput } from "react-native-paper";

import { PCButton, PCCard, PCChip, PCText } from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { appendNote, getActiveSession } from "@/lib/db/sessions";
import { useSessionStore } from "@/lib/state/session-store";
import { pushBestEffort } from "@/lib/sync/dispatcher";

const QUICK_NOTES = ["break · 15m", "meeting", "blocked", "shipped"];

export default function LogNoteScreen() {
  const router = useRouter();
  const t = useTokens();
  const refresh = useSessionStore((s) => s.refresh);

  const [note, setNote] = useState("");
  const [project, setProject] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getActiveSession().then((s) => {
      if (!s) setError("No active session. Punch in first.");
      else setProject(s.project);
    });
  }, []);

  const submit = async () => {
    const trimmed = note.trim();
    if (!trimmed) return;
    const active = await getActiveSession();
    if (!active) {
      setError("No active session.");
      return;
    }
    setSubmitting(true);
    const updated = await appendNote(active.id, trimmed);
    if (updated) pushBestEffort(updated);
    await refresh();
    setSubmitting(false);
    router.back();
  };

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        {project ? (
          <View
            style={{
              flexDirection: "row",
              alignItems: "center",
              gap: 10,
              padding: 14,
              borderRadius: t.radii.sm,
              backgroundColor: t.palette.teal50,
              borderWidth: 1,
              borderColor: t.palette.teal100,
              marginBottom: 16,
            }}
          >
            <PCChip label="LIVE" tone="live" />
            <PCText
              style={{
                fontFamily: t.fonts.mono,
                fontSize: 13,
                color: t.palette.ink900,
                flex: 1,
              }}
            >
              {project}
            </PCText>
            <PCText variant="supporting" tone="tertiary">
              attaches to current session
            </PCText>
          </View>
        ) : null}

        <PCCard padding={14}>
          <TextInput
            mode="flat"
            value={note}
            onChangeText={setNote}
            placeholder="What just happened?"
            multiline
            autoFocus
            underlineStyle={{ display: "none" }}
            style={{
              backgroundColor: "transparent",
              minHeight: 140,
              fontSize: 16,
              paddingHorizontal: 0,
            }}
          />
          <View
            style={{
              flexDirection: "row",
              justifyContent: "flex-end",
              marginTop: 8,
            }}
          >
            <PCText
              style={{
                fontFamily: t.fonts.monoRegular,
                fontSize: 11,
                color: t.palette.ink500,
              }}
            >
              {note.length}
            </PCText>
          </View>
        </PCCard>

        <PCText variant="overline" tone="tertiary" style={{ marginTop: 20, marginBottom: 10 }}>
          Quick append
        </PCText>
        <View style={styles.chipRow}>
          {QUICK_NOTES.map((q) => (
            <PCChip
              key={q}
              label={q}
              tone="neutral"
              onPress={() => setNote(note ? `${note.trimEnd()}\n${q}` : q)}
            />
          ))}
        </View>

        <View style={{ marginTop: 28, gap: 10 }}>
          <PCButton
            label="Save note"
            variant="filled"
            size="lg"
            fullWidth
            loading={submitting}
            disabled={!note.trim() || !project || submitting}
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
      </ScrollView>
      <Snackbar visible={error !== null} onDismiss={() => setError(null)} duration={4000}>
        {error ?? ""}
      </Snackbar>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
