import { View } from "react-native";
import { format, isToday, isYesterday } from "date-fns";
import { PCText } from "./PCText";
import { PCProjectDot } from "./PCProjectDot";
import { PCHairline } from "./PCHairline";
import { useTokens } from "@/lib/theme";
import { hoursBetween } from "@/lib/models/session";
import type { Session } from "@/lib/models/session";

const dayLabel = (d: Date): string => {
  if (isToday(d)) return "Today";
  if (isYesterday(d)) return "Yesterday";
  return format(d, "EEE, MMM d");
};

const rangeLabel = (startISO: string, endISO: string | null): string => {
  const start = new Date(startISO);
  if (!endISO) return `${dayLabel(start)} · ${format(start, "h:mm a")} – now`;
  const end = new Date(endISO);
  return `${dayLabel(start)} · ${format(start, "H:mm")}–${format(end, "H:mm")}`;
};

type Props = {
  session: Session;
  showDivider?: boolean;
};

export const PCSessionRow = ({ session, showDivider = true }: Props) => {
  const t = useTokens();
  const hours =
    session.endTime
      ? hoursBetween(session.startTime, session.endTime)
      : hoursBetween(session.startTime, new Date().toISOString());

  return (
    <View>
      <View style={{ flexDirection: "row", alignItems: "center", paddingVertical: 12, gap: 12 }}>
        <PCProjectDot name={session.project} />
        <View style={{ flex: 1 }}>
          <PCText
            style={{
              fontFamily: t.fonts.mono,
              fontSize: 13,
              color: t.palette.ink900,
              marginBottom: 2,
            }}
          >
            {session.project}
          </PCText>
          <PCText variant="supporting" tone="tertiary">
            {rangeLabel(session.startTime, session.endTime)}
          </PCText>
        </View>
        <PCText
          style={{
            fontFamily: t.fonts.monoSemi,
            fontSize: 14,
            color: session.endTime ? t.palette.ink900 : t.palette.teal600,
          }}
        >
          {session.endTime ? `${hours}h` : "now"}
        </PCText>
      </View>
      {showDivider ? <PCHairline /> : null}
    </View>
  );
};
