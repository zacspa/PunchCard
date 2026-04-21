import { useRef, useState } from "react";
import { StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import { CameraView, useCameraPermissions } from "expo-camera";
import { LinearGradient } from "expo-linear-gradient";
import Svg, { Path } from "react-native-svg";

import { PCButton, PCCard, PCText } from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { decodeConfigURI } from "@/lib/config/uri";
import { addProject } from "@/lib/db/projects";
import { setProjectSync } from "@/lib/config/project-sync";

export default function ScanConfigScreen() {
  const router = useRouter();
  const t = useTokens();
  const [permission, requestPermission] = useCameraPermissions();
  const [error, setError] = useState<string | null>(null);
  const handledRef = useRef(false);

  if (!permission) {
    return (
      <View style={[styles.center, { backgroundColor: t.palette.cream50 }]}>
        <PCText>Loading camera…</PCText>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={[styles.center, { backgroundColor: t.palette.cream50, gap: 16, padding: 24 }]}>
        <PCCard tone="paper" padding={20}>
          <PCText variant="title">Camera access needed</PCText>
          <PCText variant="supporting" tone="tertiary" style={{ marginTop: 6 }}>
            Scan a PunchCard QR code to import webhook URL, secret, and projects.
          </PCText>
          <View style={{ flexDirection: "row", gap: 10, marginTop: 18 }}>
            <PCButton label="Cancel" variant="outline" size="md" onPress={() => router.back()} style={{ flex: 1 }} />
            <PCButton label="Grant access" variant="filled" size="md" onPress={requestPermission} style={{ flex: 1 }} />
          </View>
        </PCCard>
      </View>
    );
  }

  const handleScan = async ({ data }: { data: string }) => {
    if (handledRef.current) return;
    const decoded = decodeConfigURI(data);
    if (!decoded) {
      setError("That QR isn't a PunchCard project code.");
      return;
    }
    handledRef.current = true;
    await addProject(decoded.name);
    await setProjectSync(decoded.name, {
      webhookURL: decoded.webhookURL,
      sharedSecret: decoded.sharedSecret,
      enabled: decoded.enabled,
    });
    router.back();
  };

  return (
    <View style={{ flex: 1, backgroundColor: "#0f0c08" }}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
        onBarcodeScanned={handleScan}
      />
      <LinearGradient
        colors={["rgba(15,12,8,0.7)", "rgba(26,23,18,0.5)", "rgba(36,28,18,0.7)"]}
        style={StyleSheet.absoluteFill}
        start={{ x: 0.1, y: 0 }}
        end={{ x: 0.9, y: 1 }}
        pointerEvents="none"
      />

      <View style={styles.overlay} pointerEvents="box-none">
        <View style={{ alignItems: "center" }}>
          <View style={styles.frameWrap}>
            <CornerBrackets />
          </View>
          <PCText
            style={{
              color: "rgba(242,232,208,0.85)",
              fontSize: 13,
              textAlign: "center",
              marginTop: 20,
            }}
          >
            Frame the code from your CLI
          </PCText>
        </View>

        <PCButton
          label="Cancel"
          variant="tonal"
          size="md"
          onPress={() => router.back()}
          style={{ alignSelf: "center", marginBottom: 24 }}
        />
      </View>

      {error ? (
        <View
          style={{
            position: "absolute",
            bottom: 100,
            left: 20,
            right: 20,
            padding: 14,
            backgroundColor: t.palette.rust600,
            borderRadius: 10,
          }}
        >
          <PCText style={{ color: t.palette.cream50, textAlign: "center" }}>{error}</PCText>
        </View>
      ) : null}
    </View>
  );
}

const CornerBrackets = () => {
  const size = 236;
  const corner = 28;
  const stroke = 3;
  const color = "#e0d9c5";
  const path = (d: string) => <Path d={d} stroke={color} strokeWidth={stroke} fill="none" strokeLinecap="round" />;

  return (
    <Svg width={size} height={size} style={{ position: "absolute" }}>
      {path(`M 2 ${corner} L 2 2 L ${corner} 2`)}
      {path(`M ${size - corner} 2 L ${size - 2} 2 L ${size - 2} ${corner}`)}
      {path(`M 2 ${size - corner} L 2 ${size - 2} L ${corner} ${size - 2}`)}
      {path(`M ${size - corner} ${size - 2} L ${size - 2} ${size - 2} L ${size - 2} ${size - corner}`)}
    </Svg>
  );
};

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: "center", justifyContent: "center" },
  overlay: { flex: 1, justifyContent: "space-between", padding: 24, paddingTop: 120 },
  frameWrap: {
    width: 236,
    height: 236,
    alignItems: "center",
    justifyContent: "center",
  },
});
