import { View, type StyleProp, type ViewStyle } from "react-native";
import Svg, { Ellipse, Line } from "react-native-svg";
import { useTokens } from "@/lib/theme";
import { PCText } from "./PCText";

type Props = {
  punched: number;
  total?: number;
  width?: number;
  height?: number;
  todayIndex?: number | null;
  showLabels?: boolean;
  style?: StyleProp<ViewStyle>;
};

const LABELS = ["M", "T", "W", "T", "F", "S", "S"];

export const PCPunchStrip = ({
  punched,
  total = 7,
  width = 280,
  height = 42,
  todayIndex = null,
  showLabels = true,
  style,
}: Props) => {
  const t = useTokens();
  const cellWidth = width / total;
  const holeWidth = cellWidth * 0.58;
  const holeHeight = height * 0.42;
  const cy = height / 2;
  const strokeColor = t.palette.cream300;
  const fillColor = t.palette.ink900;

  return (
    <View style={style}>
      <Svg width={width} height={height}>
        <Line x1={0} y1={3} x2={width} y2={3} stroke={strokeColor} strokeWidth={1} />
        <Line x1={0} y1={height - 3} x2={width} y2={height - 3} stroke={strokeColor} strokeWidth={1} />
        {Array.from({ length: total }).map((_, i) => {
          const cx = cellWidth * i + cellWidth / 2;
          const punchedHere = i < punched;
          return (
            <Ellipse
              key={i}
              cx={cx}
              cy={cy}
              rx={holeWidth / 2}
              ry={holeHeight / 2}
              fill={punchedHere ? fillColor : "transparent"}
              stroke={punchedHere ? fillColor : strokeColor}
              strokeWidth={1.5}
            />
          );
        })}
      </Svg>
      {showLabels ? (
        <View style={{ flexDirection: "row", marginTop: 6 }}>
          {LABELS.slice(0, total).map((l, i) => (
            <View key={i} style={{ width: cellWidth, alignItems: "center" }}>
              <PCText
                style={{
                  fontFamily: t.fonts.monoRegular,
                  fontSize: 10,
                  color: i === todayIndex ? t.palette.rust600 : t.palette.ink500,
                  letterSpacing: 1,
                }}
              >
                {l}
              </PCText>
            </View>
          ))}
        </View>
      ) : null}
    </View>
  );
};
