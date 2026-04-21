import { useCallback, useState } from "react";
import { Pressable, ScrollView, StyleSheet, View } from "react-native";
import { useFocusEffect, useRouter } from "expo-router";
import { TextInput } from "react-native-paper";

import {
  PCButton,
  PCCard,
  PCChevron,
  PCChip,
  PCHairline,
  PCProjectDot,
  PCSectionHead,
  PCText,
  projectTone,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { addProject } from "@/lib/db/projects";
import { listProjectConfigs, type ProjectSyncConfig } from "@/lib/config/project-sync";

export default function ProjectsScreen() {
  const t = useTokens();
  const router = useRouter();
  const [configs, setConfigs] = useState<ProjectSyncConfig[]>([]);
  const [input, setInput] = useState("");

  const load = useCallback(async () => {
    setConfigs(await listProjectConfigs());
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const handleAdd = async () => {
    const name = input.trim();
    if (!name) return;
    await addProject(name);
    setInput("");
    load();
  };

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
          <TextInput
            label="New project"
            mode="outlined"
            value={input}
            onChangeText={setInput}
            autoCapitalize="words"
            style={{ flex: 1, backgroundColor: t.palette.cream50 }}
            dense
            onSubmitEditing={handleAdd}
          />
          <PCButton
            label="Add"
            variant="filled"
            size="md"
            onPress={handleAdd}
            disabled={!input.trim()}
          />
        </View>

        {configs.length > 0 ? (
          <>
            <PCSectionHead>
              {`${configs.length} registered`}
            </PCSectionHead>
            <PCCard padding={0}>
              {configs.map((c, i) => {
                const syncStatus = statusFor(c);
                return (
                  <View key={c.name}>
                    <Pressable
                      onPress={() =>
                        router.push(`/settings/project/${encodeURIComponent(c.name)}`)
                      }
                      style={({ pressed }) => ({
                        flexDirection: "row",
                        alignItems: "center",
                        paddingVertical: 12,
                        paddingHorizontal: 16,
                        gap: 12,
                        opacity: pressed ? 0.7 : 1,
                      })}
                    >
                      <PCProjectDot name={c.name} tone={projectTone(c.name)} />
                      <View style={{ flex: 1 }}>
                        <PCText
                          style={{
                            fontFamily: t.fonts.monoSemi,
                            fontSize: 14,
                            color: t.palette.ink900,
                          }}
                        >
                          {c.name}
                        </PCText>
                        <PCText variant="caption" tone="tertiary">
                          {syncStatus.supporting}
                        </PCText>
                      </View>
                      <PCChip label={syncStatus.label} tone={syncStatus.tone} />
                      <PCChevron />
                    </Pressable>
                    {i < configs.length - 1 ? (
                      <View style={{ paddingLeft: 40 }}>
                        <PCHairline />
                      </View>
                    ) : null}
                  </View>
                );
              })}
            </PCCard>
            <PCText
              variant="caption"
              tone="tertiary"
              style={{ marginTop: 12, paddingHorizontal: 4 }}
            >
              Tap a project to configure its webhook.
            </PCText>
          </>
        ) : (
          <PCCard tone="outline" padding={18} style={{ marginTop: 20 }}>
            <PCText variant="title">No projects yet</PCText>
            <PCText variant="supporting" tone="tertiary" style={{ marginTop: 4 }}>
              Add the name of something you track time against. You'll set up its
              webhook on the next screen.
            </PCText>
          </PCCard>
        )}
      </ScrollView>
    </View>
  );
}

const statusFor = (
  c: ProjectSyncConfig,
): { label: string; tone: "teal" | "mustard" | "neutral" | "rust"; supporting: string } => {
  if (c.webhookURL && c.enabled) {
    return { label: "Synced", tone: "teal", supporting: "Syncing to sheet" };
  }
  if (c.webhookURL && !c.enabled) {
    return { label: "Paused", tone: "mustard", supporting: "Webhook set, sync off" };
  }
  return { label: "Not set", tone: "neutral", supporting: "No webhook configured" };
};

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
  rowWrap: {},
});
