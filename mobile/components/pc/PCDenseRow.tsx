import { Pressable, View, type StyleProp, type ViewStyle } from "react-native";
import { PCText } from "./PCText";
import { PCHairline } from "./PCHairline";
import { useTokens } from "@/lib/theme";

type Props = {
  title: string;
  supporting?: string;
  trailing?: React.ReactNode;
  leading?: React.ReactNode;
  onPress?: () => void;
  showDivider?: boolean;
  style?: StyleProp<ViewStyle>;
};

export const PCDenseRow = ({
  title,
  supporting,
  trailing,
  leading,
  onPress,
  showDivider = true,
  style,
}: Props) => {
  const Wrapper: React.ElementType = onPress ? Pressable : View;

  return (
    <View>
      <Wrapper
        onPress={onPress}
        style={[
          {
            minHeight: 48,
            paddingVertical: 10,
            paddingHorizontal: 16,
            flexDirection: "row",
            alignItems: "center",
            gap: 12,
          },
          style,
        ]}
      >
        {leading ? <View>{leading}</View> : null}
        <View style={{ flex: 1 }}>
          <PCText
            style={{ fontSize: 14, lineHeight: 18 }}
            numberOfLines={1}
          >
            {title}
          </PCText>
          {supporting ? (
            <PCText variant="caption" tone="tertiary" numberOfLines={1}>
              {supporting}
            </PCText>
          ) : null}
        </View>
        {trailing ? <View>{trailing}</View> : null}
      </Wrapper>
      {showDivider ? <DividerSlot /> : null}
    </View>
  );
};

const DividerSlot = () => (
  <View style={{ paddingLeft: 16 }}>
    <PCHairline />
  </View>
);

export const PCSectionHead = ({ children }: { children: string }) => {
  const t = useTokens();
  return (
    <View style={{ paddingHorizontal: 4, marginBottom: 8, marginTop: 20 }}>
      <PCText variant="overline" tone="tertiary">
        {children}
      </PCText>
    </View>
  );
};

export const PCChevron = () => {
  const t = useTokens();
  return (
    <PCText style={{ color: t.palette.ink300, fontSize: 18 }}>›</PCText>
  );
};
