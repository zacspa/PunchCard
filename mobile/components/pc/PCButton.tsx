import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  View,
  type PressableProps,
  type StyleProp,
  type ViewStyle,
} from "react-native";
import { useTokens } from "@/lib/theme";
import { PCText } from "./PCText";

type Variant = "filled" | "rust" | "tonal" | "outline" | "ghost";
type Size = "sm" | "md" | "lg" | "xl";

type Props = Omit<PressableProps, "style"> & {
  label: string;
  variant?: Variant;
  size?: Size;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  loading?: boolean;
  disabled?: boolean;
  fullWidth?: boolean;
  style?: StyleProp<ViewStyle>;
};

const sizeSpec = {
  sm: { height: 36, padH: 14, fontSize: 13 },
  md: { height: 48, padH: 18, fontSize: 15 },
  lg: { height: 56, padH: 22, fontSize: 16 },
  xl: { height: 72, padH: 26, fontSize: 18 },
} as const;

export const PCButton = ({
  label,
  variant = "filled",
  size = "md",
  leading,
  trailing,
  loading = false,
  disabled = false,
  fullWidth = false,
  style,
  onPress,
  ...rest
}: Props) => {
  const t = useTokens();
  const s = sizeSpec[size];
  const isDisabled = disabled || loading;

  const bg = bgFor(variant, t, isDisabled);
  const fg = fgFor(variant, t, isDisabled);
  const border = borderFor(variant, t, isDisabled);

  return (
    <Pressable
      {...rest}
      disabled={isDisabled}
      onPress={loading ? undefined : onPress}
      style={({ pressed }) => [
        {
          height: s.height,
          paddingHorizontal: s.padH,
          borderRadius: s.height / 2,
          backgroundColor: bg,
          borderWidth: border ? 1.5 : 0,
          borderColor: border ?? undefined,
          opacity: pressed && !isDisabled ? 0.85 : 1,
          alignItems: "center",
          justifyContent: "center",
          flexDirection: "row",
          alignSelf: fullWidth ? "stretch" : "flex-start",
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={fg} size="small" />
      ) : (
        <View style={styles.inner}>
          {leading ? <View style={styles.leading}>{leading}</View> : null}
          <PCText
            style={{
              fontFamily: t.fonts.bodySemi,
              fontSize: s.fontSize,
              color: fg,
              textAlign: "center",
            }}
          >
            {label}
          </PCText>
          {trailing ? <View style={styles.trailing}>{trailing}</View> : null}
        </View>
      )}
    </Pressable>
  );
};

const bgFor = (v: Variant, t: ReturnType<typeof useTokens>, disabled: boolean) => {
  if (disabled) return t.palette.cream200;
  switch (v) {
    case "filled":
      return t.palette.teal600;
    case "rust":
      return t.palette.rust600;
    case "tonal":
      return t.palette.teal100;
    case "outline":
    case "ghost":
      return "transparent";
  }
};

const fgFor = (v: Variant, t: ReturnType<typeof useTokens>, disabled: boolean) => {
  if (disabled) return t.palette.ink300;
  switch (v) {
    case "filled":
    case "rust":
      return t.palette.cream50;
    case "tonal":
      return t.palette.teal600;
    case "outline":
      return t.palette.ink900;
    case "ghost":
      return t.palette.ink900;
  }
};

const borderFor = (v: Variant, t: ReturnType<typeof useTokens>, disabled: boolean) => {
  if (v !== "outline") return null;
  return disabled ? t.palette.cream300 : t.palette.ink900;
};

const styles = StyleSheet.create({
  inner: { flexDirection: "row", alignItems: "center" },
  leading: { marginRight: 8 },
  trailing: { marginLeft: 8 },
});
