import { ScrollView, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";

import {
  PCCard,
  PCChevron,
  PCDenseRow,
  PCSectionHead,
  PCText,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";

export default function SettingsScreen() {
  const router = useRouter();
  const t = useTokens();

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body}>
        <PCSectionHead>Projects</PCSectionHead>
        <PCText variant="supporting" tone="tertiary" style={{ marginTop: -4, marginBottom: 12 }}>
          Every project has its own webhook and secret. Tap a project to set or
          change its Google Sheet target.
        </PCText>
        <PCCard padding={0}>
          <PCDenseRow
            title="Manage projects"
            supporting="Add, remove, and configure sync per project"
            onPress={() => router.push("/settings/projects")}
            trailing={<PCChevron />}
            showDivider={false}
          />
        </PCCard>

        <PCSectionHead>Transfer</PCSectionHead>
        <PCText variant="supporting" tone="tertiary" style={{ marginTop: -4, marginBottom: 12 }}>
          Import a project's webhook + secret from another device via QR.
        </PCText>
        <PCCard padding={0}>
          <PCDenseRow
            title="Scan project QR"
            supporting="Import a project and its sync config"
            onPress={() => router.push("/settings/scan")}
            trailing={<PCChevron />}
            showDivider={false}
          />
        </PCCard>

        <PCText
          variant="caption"
          tone="tertiary"
          style={{
            fontFamily: t.fonts.monoRegular,
            textAlign: "center",
            marginTop: 32,
            marginBottom: 12,
          }}
        >
          PunchCard Mobile · 1.0.0
        </PCText>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
});
