import { View, type StyleProp, type ViewStyle } from "react-native";
import { PCText } from "./PCText";
import { useTokens } from "@/lib/theme";

type Props = {
  size?: number;
  style?: StyleProp<ViewStyle>;
};

export const PCMark = ({ size = 22, style }: Props) => {
  const t = useTokens();
  const dot = size * 0.28;
  return (
    <View style={[{ flexDirection: "row", alignItems: "baseline" }, style]}>
      <PCText
        style={{
          fontFamily: t.fonts.display,
          fontSize: size,
          lineHeight: size * 1.1,
          color: t.palette.ink900,
        }}
      >
        punch
      </PCText>
      <View
        style={{
          width: dot,
          height: dot,
          borderRadius: dot / 2,
          backgroundColor: t.palette.rust600,
          marginHorizontal: 3,
          transform: [{ translateY: -dot * 0.4 }],
        }}
      />
      <PCText
        style={{
          fontFamily: t.fonts.display,
          fontSize: size,
          lineHeight: size * 1.1,
          color: t.palette.ink900,
        }}
      >
        card
      </PCText>
    </View>
  );
};
