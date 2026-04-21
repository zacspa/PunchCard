import { useCallback, useEffect, useState } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useFocusEffect, useLocalSearchParams, useRouter } from "expo-router";
import { Snackbar, Switch, TextInput } from "react-native-paper";

import {
  PCButton,
  PCCard,
  PCChevron,
  PCDenseRow,
  PCProjectDot,
  PCSectionHead,
  PCText,
  projectTone,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import {
  getProjectSyncConfig,
  setProjectSync,
} from "@/lib/config/project-sync";
import { removeProject } from "@/lib/db/projects";
import { postEnvelope } from "@/lib/sync/client";
import { buildUpsertEnvelope } from "@/lib/sync/payload";

export default function ProjectDetailScreen() {
  const router = useRouter();
  const t = useTokens();
  const { name: paramName } = useLocalSearchParams<{ name: string }>();
  const name = String(paramName ?? "");

  const [webhook, setWebhook] = useState("");
  const [secret, setSecret] = useState("");
  const [enabled, setEnabled] = useState(false);
  const [showSecret, setShowSecret] = useState(false);
  const [loading, setLoading] = useState(true);
  const [testing, setTesting] = useState(false);
  const [snack, setSnack] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!name) return;
    const c = await getProjectSyncConfig(name);
    if (c) {
      setWebhook(c.webhookURL ?? "");
      setSecret(c.sharedSecret ?? "");
      setEnabled(c.enabled);
    }
    setLoading(false);
  }, [name]);

  useEffect(() => {
    load();
  }, [load]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const webhookValid =
    webhook.trim().length === 0 || /^https:\/\/.+/i.test(webhook.trim());

  const save = async () => {
    await setProjectSync(name, {
      webhookURL: webhook,
      sharedSecret: secret,
      enabled,
    });
    setSnack("Saved.");
  };

  const toggleEnabled = async (val: boolean) => {
    setEnabled(val);
    await setProjectSync(name, { enabled: val });
  };

  const test = async () => {
    setTesting(true);
    await save();
    const result = await postEnvelope(
      {
        webhookURL: webhook.trim() || null,
        sharedSecret: secret.trim() || null,
        enabled: true,
      },
      buildUpsertEnvelope([]),
    );
    setTesting(false);
    setSnack(
      result.ok ? `✓ Connection OK (HTTP ${result.status})` : `✗ ${result.message}`,
    );
  };

  const onDelete = async () => {
    await removeProject(name);
    router.back();
  };

  if (loading) return null;

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        <View style={styles.heroRow}>
          <PCProjectDot name={name} tone={projectTone(name)} size={16} />
          <PCText
            style={{
              fontFamily: t.fonts.monoSemi,
              fontSize: 18,
              color: t.palette.ink900,
              flex: 1,
            }}
          >
            {name}
          </PCText>
        </View>

        <PCSectionHead>Google Sheet sync</PCSectionHead>
        <PCText variant="supporting" tone="tertiary" style={{ marginTop: -4, marginBottom: 12 }}>
          Each project can point to its own Apps Script web app. Sessions for this
          project push only to the URL below.
        </PCText>

        <TextInput
          label="Webhook URL"
          mode="outlined"
          value={webhook}
          onChangeText={setWebhook}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="url"
          placeholder="https://script.google.com/…"
          dense
          style={{ backgroundColor: t.palette.cream50 }}
          error={!webhookValid}
        />

        <TextInput
          label="Shared secret"
          mode="outlined"
          value={secret}
          onChangeText={setSecret}
          autoCapitalize="none"
          autoCorrect={false}
          secureTextEntry={!showSecret}
          dense
          style={{ marginTop: 10, backgroundColor: t.palette.cream50 }}
          right={
            <TextInput.Icon
              icon={showSecret ? "eye-off" : "eye"}
              onPress={() => setShowSecret((v) => !v)}
            />
          }
        />

        <PCCard padding={0} style={{ marginTop: 14 }}>
          <PCDenseRow
            title="Enable sync for this project"
            supporting={enabled ? "Sessions for this project push to the sheet" : "Paused — sessions queue until re-enabled"}
            trailing={
              <Switch
                value={enabled}
                onValueChange={toggleEnabled}
                trackColor={{ false: t.palette.cream300, true: t.palette.teal600 }}
                thumbColor={t.palette.cream50}
              />
            }
            showDivider={false}
          />
        </PCCard>

        <View style={{ flexDirection: "row", gap: 10, marginTop: 14 }}>
          <PCButton
            label="Save"
            variant="outline"
            size="md"
            disabled={!webhookValid}
            onPress={save}
            style={{ flex: 1 }}
          />
          <PCButton
            label="Test connection"
            variant="tonal"
            size="md"
            loading={testing}
            disabled={!webhookValid || !webhook.trim() || testing}
            onPress={test}
            style={{ flex: 1 }}
          />
        </View>

        <PCSectionHead>Transfer</PCSectionHead>

        <PCCard padding={0}>
          <PCDenseRow
            title="Show QR"
            supporting={webhook.trim() ? "Share this project's config to another phone" : "Set a webhook URL first"}
            onPress={
              webhook.trim()
                ? () => router.push({ pathname: "/settings/share", params: { name } })
                : undefined
            }
            trailing={<PCChevron />}
            showDivider={false}
          />
        </PCCard>

        <PCSectionHead>Danger</PCSectionHead>
        <PCButton
          label="Delete project"
          variant="ghost"
          size="md"
          fullWidth
          onPress={onDelete}
        />
      </ScrollView>

      <Snackbar visible={snack !== null} onDismiss={() => setSnack(null)} duration={3500}>
        {snack ?? ""}
      </Snackbar>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
  heroRow: { flexDirection: "row", alignItems: "center", gap: 12, marginBottom: 16 },
});
