import { Pressable, View, type StyleProp, type ViewStyle } from "react-native";
import { PCText } from "./PCText";
import { useTokens } from "@/lib/theme";

type Props = {
  label: string;
  placeholder?: boolean;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  onPress?: () => void;
  style?: StyleProp<ViewStyle>;
};

/**
 * A tappable field that looks like a form input, not a pill CTA. Text is
 * left-aligned so an optional leading icon and value read left-to-right.
 */
export const PCFieldButton = ({
  label,
  placeholder = false,
  leading,
  trailing,
  onPress,
  style,
}: Props) => {
  const t = useTokens();
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        {
          minHeight: 52,
          paddingVertical: 12,
          paddingHorizontal: 16,
          borderRadius: t.radii.md,
          borderWidth: 1.5,
          borderColor: t.palette.ink900,
          backgroundColor: "transparent",
          flexDirection: "row",
          alignItems: "center",
          gap: 12,
          opacity: pressed ? 0.75 : 1,
        },
        style,
      ]}
    >
      {leading ? <View>{leading}</View> : null}
      <PCText
        numberOfLines={1}
        style={{
          flex: 1,
          fontFamily: t.fonts.bodyMedium,
          fontSize: 15,
          color: placeholder ? t.palette.ink500 : t.palette.ink900,
        }}
      >
        {label}
      </PCText>
      {trailing ? <View>{trailing}</View> : null}
    </Pressable>
  );
};
