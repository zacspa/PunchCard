import { View, type StyleProp, type ViewStyle } from "react-native";
import { useTokens } from "@/lib/theme";

export const PCHairline = ({ style }: { style?: StyleProp<ViewStyle> }) => {
  const t = useTokens();
  return <View style={[{ height: 1, backgroundColor: t.palette.cream200 }, style]} />;
};
