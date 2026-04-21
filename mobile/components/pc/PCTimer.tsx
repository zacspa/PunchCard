import { useEffect, useState } from "react";
import { View, type StyleProp, type ViewStyle } from "react-native";
import { useTokens } from "@/lib/theme";
import { PCText } from "./PCText";

type Size = "sm" | "md" | "lg";

type Props = {
  startedAt: string;
  size?: Size;
  live?: boolean;
  style?: StyleProp<ViewStyle>;
};

const sizeSpec = {
  sm: 32,
  md: 52,
  lg: 68,
} as const;

const formatElapsed = (ms: number): { hh: string; mm: string; ss: string } => {
  const total = Math.max(0, Math.floor(ms / 1000));
  const hh = Math.floor(total / 3600);
  const mm = Math.floor((total % 3600) / 60);
  const ss = total % 60;
  return {
    hh: String(hh).padStart(2, "0"),
    mm: String(mm).padStart(2, "0"),
    ss: String(ss).padStart(2, "0"),
  };
};

export const PCTimer = ({ startedAt, size = "md", live = true, style }: Props) => {
  const t = useTokens();
  const [now, setNow] = useState(() => Date.now());
  const [blink, setBlink] = useState(true);

  useEffect(() => {
    if (!live) return;
    const t1 = setInterval(() => setNow(Date.now()), 1000);
    const t2 = setInterval(() => setBlink((b) => !b), 500);
    return () => {
      clearInterval(t1);
      clearInterval(t2);
    };
  }, [live]);

  const { hh, mm, ss } = formatElapsed(now - new Date(startedAt).getTime());
  const fs = sizeSpec[size];

  const colonStyle = {
    fontFamily: t.fonts.monoSemi,
    fontSize: fs,
    lineHeight: fs * 1.02,
    color: t.palette.ink900,
    opacity: live && !blink ? 0.25 : 1,
  };
  const digitStyle = {
    fontFamily: t.fonts.monoSemi,
    fontSize: fs,
    lineHeight: fs * 1.02,
    color: t.palette.ink900,
    letterSpacing: -0.5,
  };

  return (
    <View style={[{ flexDirection: "row", alignItems: "baseline" }, style]}>
      <PCText style={digitStyle}>{hh}</PCText>
      <PCText style={colonStyle}>:</PCText>
      <PCText style={digitStyle}>{mm}</PCText>
      <PCText style={colonStyle}>:</PCText>
      <PCText style={[digitStyle, { opacity: 0.85 }]}>{ss}</PCText>
    </View>
  );
};
