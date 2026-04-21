import { Pressable, View, type StyleProp, type ViewStyle } from "react-native";
import { useTokens } from "@/lib/theme";
import { PCText } from "./PCText";

type Tone = "neutral" | "teal" | "rust" | "olive" | "mustard" | "live";

type Props = {
  label: string;
  tone?: Tone;
  selected?: boolean;
  onPress?: () => void;
  leading?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
};

export const PCChip = ({ label, tone = "neutral", selected = false, onPress, leading, style }: Props) => {
  const t = useTokens();
  const spec = chipSpec(tone, t, selected);
  const Wrapper: React.ElementType = onPress ? Pressable : View;

  return (
    <Wrapper
      onPress={onPress}
      style={[
        {
          height: 28,
          minHeight: 28,
          paddingHorizontal: 12,
          borderRadius: 14,
          backgroundColor: spec.bg,
          borderWidth: spec.border ? 1 : 0,
          borderColor: spec.border ?? undefined,
          flexDirection: "row",
          alignItems: "center",
          gap: 6,
        },
        style,
      ]}
    >
      {leading}
      <PCText
        style={{
          fontFamily: t.fonts.bodySemi,
          fontSize: 12,
          color: spec.fg,
          letterSpacing: 0.2,
        }}
      >
        {label}
      </PCText>
    </Wrapper>
  );
};

const chipSpec = (tone: Tone, t: ReturnType<typeof useTokens>, selected: boolean) => {
  switch (tone) {
    case "neutral":
      return selected
        ? { bg: t.palette.ink900, fg: t.palette.cream50, border: null }
        : { bg: t.palette.cream100, fg: t.palette.ink700, border: t.palette.cream200 };
    case "teal":
      return { bg: t.palette.teal100, fg: t.palette.teal600, border: null };
    case "rust":
      return { bg: t.palette.rust100, fg: t.palette.rust600, border: null };
    case "olive":
      return { bg: t.palette.olive100, fg: t.palette.olive600, border: null };
    case "mustard":
      return { bg: t.palette.mustard100, fg: t.palette.mustard600, border: null };
    case "live":
      return { bg: t.palette.rust600, fg: t.palette.cream50, border: null };
  }
};
