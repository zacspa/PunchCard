import { useEffect, useState } from "react";
import { ScrollView, StyleSheet, View, useWindowDimensions } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import QRCode from "react-native-qrcode-svg";

import {
  PCButton,
  PCCard,
  PCProjectDot,
  PCText,
  projectTone,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { getProjectSyncConfig } from "@/lib/config/project-sync";
import { encodeProjectURI } from "@/lib/config/uri";

export default function ShareConfigScreen() {
  const router = useRouter();
  const t = useTokens();
  const { width } = useWindowDimensions();
  const { name: paramName } = useLocalSearchParams<{ name: string }>();
  const name = String(paramName ?? "");

  const [uri, setUri] = useState<string | null>(null);
  const [hasSecret, setHasSecret] = useState(false);

  useEffect(() => {
    (async () => {
      if (!name) return;
      const config = await getProjectSyncConfig(name);
      if (!config?.webhookURL) {
        setUri(null);
        return;
      }
      setUri(encodeProjectURI(config));
      setHasSecret(!!config.sharedSecret);
    })();
  }, [name]);

  const qrSize = Math.min(width - 80, 300);

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body}>
        <View style={styles.hero}>
          <PCProjectDot name={name} tone={projectTone(name)} size={14} />
          <PCText
            style={{
              fontFamily: t.fonts.monoSemi,
              fontSize: 15,
              color: t.palette.ink900,
            }}
          >
            {name}
          </PCText>
        </View>

        <PCCard padding={24} style={{ alignItems: "center" }}>
          {uri ? (
            <>
              <PCText variant="overline" tone="tertiary">
                Share project
              </PCText>
              <View
                style={{
                  marginTop: 18,
                  padding: 16,
                  backgroundColor: "#ffffff",
                  borderRadius: t.radii.sm,
                }}
              >
                <QRCode value={uri} size={qrSize} color="#2a2418" backgroundColor="#ffffff" />
              </View>
              <PCText
                variant="supporting"
                tone="secondary"
                style={{ textAlign: "center", marginTop: 20, lineHeight: 19 }}
              >
                Scan from another device to add this project with its webhook
                {hasSecret ? " and secret" : ""}.
              </PCText>
              {hasSecret ? (
                <PCText
                  variant="caption"
                  tone="tertiary"
                  style={{ textAlign: "center", marginTop: 8, lineHeight: 16 }}
                >
                  Contains this project's shared secret. Don't screenshot or
                  share publicly.
                </PCText>
              ) : null}
            </>
          ) : (
            <PCText variant="body" tone="tertiary" style={{ textAlign: "center" }}>
              No webhook URL set for this project. Configure it first.
            </PCText>
          )}
        </PCCard>

        <PCButton
          label="Done"
          variant="filled"
          size="md"
          fullWidth
          onPress={() => router.back()}
          style={{ marginTop: 20 }}
        />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
  hero: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    marginBottom: 16,
  },
});
