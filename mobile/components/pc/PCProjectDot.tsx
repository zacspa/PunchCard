import { View, type StyleProp, type ViewStyle } from "react-native";
import { useTokens } from "@/lib/theme";

type Tone = "teal" | "rust" | "olive" | "mustard" | "neutral";

const tonesCycle: Tone[] = ["teal", "olive", "rust", "mustard"];

export const projectTone = (name: string): Tone => {
  if (!name) return "neutral";
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) | 0;
  const idx = Math.abs(hash) % tonesCycle.length;
  return tonesCycle[idx];
};

type Props = {
  name?: string;
  tone?: Tone;
  size?: number;
  style?: StyleProp<ViewStyle>;
};

export const PCProjectDot = ({ name, tone, size = 10, style }: Props) => {
  const t = useTokens();
  const resolved = tone ?? (name ? projectTone(name) : "neutral");
  const color = {
    teal: t.palette.teal600,
    rust: t.palette.rust600,
    olive: t.palette.olive600,
    mustard: t.palette.mustard600,
    neutral: t.palette.ink500,
  }[resolved];
  return (
    <View
      style={[
        { width: size, height: size, borderRadius: size / 2, backgroundColor: color },
        style,
      ]}
    />
  );
};
