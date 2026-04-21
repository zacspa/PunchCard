import { View, type StyleProp, type ViewStyle } from "react-native";
import { useTokens } from "@/lib/theme";

type Tone = "paper" | "teal" | "rust" | "inset" | "outline";

type Props = {
  tone?: Tone;
  padding?: number;
  radius?: number;
  style?: StyleProp<ViewStyle>;
  children?: React.ReactNode;
};

export const PCCard = ({ tone = "paper", padding = 20, radius, style, children }: Props) => {
  const t = useTokens();
  const { bg, border } = cardSpec(tone, t);
  return (
    <View
      style={[
        {
          backgroundColor: bg,
          borderRadius: radius ?? t.radii.md,
          padding,
          borderWidth: border ? 1 : 0,
          borderColor: border ?? undefined,
          shadowColor: t.palette.ink900,
          shadowOffset: { width: 0, height: 1 },
          shadowOpacity: t.scheme === "dark" ? 0.35 : 0.06,
          shadowRadius: 0,
          elevation: 1,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
};

const cardSpec = (tone: Tone, t: ReturnType<typeof useTokens>) => {
  switch (tone) {
    case "paper":
      return { bg: t.palette.cream100, border: null };
    case "teal":
      return { bg: t.palette.teal100, border: null };
    case "rust":
      return { bg: t.palette.rust100, border: null };
    case "inset":
      return { bg: t.palette.cream50, border: t.palette.cream200 };
    case "outline":
      return { bg: "transparent", border: t.palette.cream300 };
  }
};
