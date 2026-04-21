import { View, type StyleProp, type ViewStyle } from "react-native";
import Svg, { Rect } from "react-native-svg";
import { format } from "date-fns";
import { PCText } from "./PCText";
import { useTokens } from "@/lib/theme";

type Action = "in" | "out";

type Props = {
  action: Action;
  time: Date;
  project?: string;
  hours?: number | null;
  inTime?: Date | null;
  showPunchEdge?: boolean;
  style?: StyleProp<ViewStyle>;
};

/**
 * The punch-card "stamp" card. Used in Punch In (preview of what'll be stamped)
 * and in Punch Out (the hours reveal after stopping).
 */
export const PCStampCard = ({
  action,
  time,
  project,
  hours,
  inTime,
  showPunchEdge = false,
  style,
}: Props) => {
  const t = useTokens();
  const isOut = action === "out";

  return (
    <View
      style={[
        {
          backgroundColor: t.palette.cream100,
          borderWidth: 1,
          borderColor: t.palette.cream300,
          borderRadius: t.radii.md,
          paddingHorizontal: 24,
          paddingTop: 22,
          paddingBottom: 20,
          position: "relative",
          shadowColor: t.palette.ink900,
          shadowOffset: { width: 0, height: 1 },
          shadowOpacity: t.scheme === "dark" ? 0.4 : 0.08,
          shadowRadius: 2,
          elevation: 1,
        },
        style,
      ]}
    >
      {showPunchEdge ? <PunchEdge /> : null}

      {/* Rust ink dot (top-right corner) */}
      <View
        style={{
          position: "absolute",
          top: -6,
          right: -6,
          width: 18,
          height: 18,
          borderRadius: 9,
          backgroundColor: t.palette.rust600,
          shadowColor: t.palette.rust600,
          shadowOffset: { width: 0, height: 0 },
          shadowOpacity: 0.4,
          shadowRadius: 4,
        }}
      />

      <PCText
        style={{
          fontFamily: t.fonts.bodySemi,
          fontSize: 11,
          letterSpacing: 1.4,
          color: isOut ? t.palette.rust600 : t.palette.ink500,
          textTransform: "uppercase",
        }}
      >
        {isOut ? "Punched out" : "In"} · {format(time, "MMM d").toUpperCase()}
      </PCText>

      {project ? (
        <PCText
          style={{
            fontFamily: t.fonts.monoSemi,
            fontSize: 14,
            color: t.palette.ink700,
            marginTop: 4,
          }}
        >
          {project}
        </PCText>
      ) : null}

      {isOut && hours != null ? (
        <View style={{ flexDirection: "row", alignItems: "baseline", marginTop: 6 }}>
          <PCText
            style={{
              fontFamily: t.fonts.monoSemi,
              fontSize: 56,
              lineHeight: 62,
              color: t.palette.rust600,
              letterSpacing: -1.5,
            }}
          >
            {formatHoursAsClock(hours)}
          </PCText>
        </View>
      ) : (
        <PCText
          style={{
            fontFamily: t.fonts.monoSemi,
            fontSize: 34,
            lineHeight: 40,
            color: t.palette.ink900,
            letterSpacing: -0.6,
            marginTop: 4,
          }}
        >
          {format(time, "HH:mm")}
        </PCText>
      )}

      {isOut && inTime ? (
        <View style={{ flexDirection: "row", justifyContent: "space-between", marginTop: 14 }}>
          <PCText
            style={{
              fontFamily: t.fonts.monoRegular,
              fontSize: 12,
              color: t.palette.ink500,
            }}
          >
            IN {format(inTime, "HH:mm")}
          </PCText>
          <PCText
            style={{
              fontFamily: t.fonts.monoRegular,
              fontSize: 12,
              color: t.palette.ink500,
            }}
          >
            OUT {format(time, "HH:mm")}
          </PCText>
        </View>
      ) : null}
    </View>
  );
};

const PunchEdge = () => {
  const t = useTokens();
  const width = 280;
  const height = 12;
  const holes = 10;
  const holeW = 12;
  const holeH = 5;
  const spacing = (width - holeW * holes) / (holes + 1);

  return (
    <View
      style={{
        position: "absolute",
        top: 8,
        left: 0,
        right: 0,
        alignItems: "center",
      }}
      pointerEvents="none"
    >
      <Svg width={width} height={height}>
        {Array.from({ length: holes }).map((_, i) => (
          <Rect
            key={i}
            x={spacing + (spacing + holeW) * i}
            y={(height - holeH) / 2}
            width={holeW}
            height={holeH}
            rx={1}
            fill={t.palette.cream50}
            stroke={t.palette.cream300}
            strokeWidth={0.8}
          />
        ))}
      </Svg>
    </View>
  );
};

const formatHoursAsClock = (hours: number): string => {
  const total = Math.round(hours * 3600);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
};
