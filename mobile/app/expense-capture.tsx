import { useRef, useState } from "react";
import { Pressable, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import { CameraView, useCameraPermissions, type FlashMode } from "expo-camera";
import { Icon } from "react-native-paper";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Svg, { Path } from "react-native-svg";

import { PCButton, PCCard, PCChip, PCText } from "@/components/pc";
import { useTokens } from "@/lib/theme";

export default function ExpenseCaptureScreen() {
  const router = useRouter();
  const t = useTokens();
  const insets = useSafeAreaInsets();
  const [permission, requestPermission] = useCameraPermissions();
  const [flash, setFlash] = useState<FlashMode>("off");
  const [busy, setBusy] = useState(false);
  const cameraRef = useRef<CameraView | null>(null);

  if (!permission) {
    return (
      <View style={[styles.center, { backgroundColor: "#0f0c08" }]}>
        <PCText style={{ color: t.palette.cream50 }}>Loading camera…</PCText>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={[styles.center, { backgroundColor: t.palette.cream50, gap: 16, padding: 24 }]}>
        <PCCard tone="paper" padding={20}>
          <PCText variant="title">Camera access needed</PCText>
          <PCText variant="supporting" tone="tertiary" style={{ marginTop: 6 }}>
            PunchCard uses the camera to snap a receipt for an expense.
          </PCText>
          <View style={{ flexDirection: "row", gap: 10, marginTop: 18 }}>
            <PCButton
              label="Cancel"
              variant="outline"
              size="md"
              onPress={() => router.back()}
              style={{ flex: 1 }}
            />
            <PCButton
              label="Grant access"
              variant="filled"
              size="md"
              onPress={requestPermission}
              style={{ flex: 1 }}
            />
          </View>
        </PCCard>
      </View>
    );
  }

  const snap = async () => {
    if (busy || !cameraRef.current) return;
    setBusy(true);
    try {
      const picture = await cameraRef.current.takePictureAsync({
        quality: 0.85,
        skipProcessing: false,
      });
      if (!picture?.uri) throw new Error("Capture failed.");
      router.replace({
        pathname: "/expense-new",
        params: { sourceImageURI: picture.uri },
      });
    } catch {
      setBusy(false);
    }
  };

  const toggleFlash = () => {
    setFlash((f) => (f === "off" ? "on" : f === "on" ? "auto" : "off"));
  };

  return (
    <View style={{ flex: 1, backgroundColor: "#0f0c08" }}>
      <CameraView
        ref={cameraRef}
        style={StyleSheet.absoluteFill}
        facing="back"
        flash={flash}
        autofocus="on"
      />

      <View
        pointerEvents="box-none"
        style={[
          styles.topBar,
          { paddingTop: insets.top + 12, paddingLeft: insets.left + 16, paddingRight: insets.right + 16 },
        ]}
      >
        <IconCircle icon="close" onPress={() => router.back()} />
        <PCText style={styles.topTitle}>Snap receipt</PCText>
        <IconCircle
          icon={flash === "off" ? "flash-off" : flash === "on" ? "flash" : "flash-auto"}
          onPress={toggleFlash}
          active={flash !== "off"}
        />
      </View>

      <View style={styles.frameWrap} pointerEvents="none">
        <ReceiptBrackets />
        <PCChip label="Frame the receipt" tone="teal" style={{ marginTop: 16 }} />
      </View>

      <View
        style={[
          styles.bottomBar,
          {
            paddingBottom: insets.bottom + 18,
            paddingLeft: insets.left + 24,
            paddingRight: insets.right + 24,
          },
        ]}
      >
        <View style={{ width: 52 }} />
        <Pressable onPress={snap} disabled={busy} accessibilityLabel="Capture receipt">
          <View style={styles.shutterRing}>
            <View style={[styles.shutterFill, { backgroundColor: t.palette.rust600 }]} />
          </View>
        </Pressable>
        <View style={{ width: 52 }} />
      </View>
    </View>
  );
}

const IconCircle = ({
  icon,
  onPress,
  active = false,
}: {
  icon: string;
  onPress: () => void;
  active?: boolean;
}) => {
  const t = useTokens();
  return (
    <Pressable
      onPress={onPress}
      style={{
        width: 40,
        height: 40,
        borderRadius: 20,
        backgroundColor: active ? t.palette.teal600 : "rgba(15,12,8,0.55)",
        alignItems: "center",
        justifyContent: "center",
        borderWidth: 1,
        borderColor: "rgba(242,232,208,0.18)",
      }}
      accessibilityRole="button"
    >
      <Icon source={icon} size={20} color={t.palette.cream50} />
    </Pressable>
  );
};

const ReceiptBrackets = () => {
  const width = 240;
  const height = 320;
  const corner = 28;
  const stroke = 3;
  const color = "#6bbfb3";
  const path = (d: string) => (
    <Path d={d} stroke={color} strokeWidth={stroke} fill="none" strokeLinecap="round" />
  );

  return (
    <Svg width={width} height={height}>
      {path(`M 2 ${corner} L 2 2 L ${corner} 2`)}
      {path(`M ${width - corner} 2 L ${width - 2} 2 L ${width - 2} ${corner}`)}
      {path(`M 2 ${height - corner} L 2 ${height - 2} L ${corner} ${height - 2}`)}
      {path(
        `M ${width - corner} ${height - 2} L ${width - 2} ${height - 2} L ${width - 2} ${height - corner}`,
      )}
    </Svg>
  );
};

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: "center", justifyContent: "center" },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  topTitle: {
    color: "#f2e8d0",
    fontSize: 16,
    fontFamily: "Fraunces_600SemiBold",
  },
  frameWrap: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  bottomBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingTop: 18,
  },
  shutterRing: {
    width: 78,
    height: 78,
    borderRadius: 39,
    borderWidth: 4,
    borderColor: "#f2e8d0",
    alignItems: "center",
    justifyContent: "center",
  },
  shutterFill: {
    width: 62,
    height: 62,
    borderRadius: 31,
  },
});
