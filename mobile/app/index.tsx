import { useCallback } from "react";
import { ScrollView, StyleSheet, View } from "react-native";
import { useFocusEffect, useRouter } from "expo-router";
import { IconButton } from "react-native-paper";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { format, formatDistanceToNowStrict, isSameMonth } from "date-fns";

import {
  PCButton,
  PCCard,
  PCChip,
  PCHairline,
  PCMark,
  PCPunchStrip,
  PCSessionRow,
  PCText,
  PCTimer,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { useSessionStore } from "@/lib/state/session-store";

export default function Home() {
  const router = useRouter();
  const t = useTokens();
  const insets = useSafeAreaInsets();
  const { active, pendingSync, recents, todayHours, week, lastEnded, refresh } = useSessionStore();

  useFocusEffect(
    useCallback(() => {
      refresh();
    }, [refresh]),
  );

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <View
        style={[
          styles.appbar,
          {
            marginTop: insets.top,
            paddingLeft: 20 + insets.left,
            paddingRight: 20 + insets.right,
          },
        ]}
      >
        <PCMark size={22} />
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          {pendingSync > 0 ? (
            <PCChip
              label={`${pendingSync} pending`}
              tone="mustard"
              style={{ marginRight: 4 }}
            />
          ) : null}
          <IconButton
            icon="cog-outline"
            size={22}
            iconColor={t.palette.ink700}
            onPress={() => router.push("/settings")}
            accessibilityLabel="Settings"
          />
        </View>
      </View>

      <ScrollView
        contentContainerStyle={[
          styles.body,
          {
            paddingLeft: 20 + insets.left,
            paddingRight: 20 + insets.right,
            paddingBottom: 40 + insets.bottom,
          },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {active ? (
          <ActiveSessionCard />
        ) : (
          <>
            <WeekSummaryCard />
            <PCButton
              label="Punch In"
              variant="rust"
              size="xl"
              fullWidth
              onPress={() => router.push("/punch-in")}
              style={{ marginTop: 8 }}
            />
            {lastEnded ? (
              <PCText
                variant="supporting"
                tone="tertiary"
                style={{
                  textAlign: "center",
                  fontFamily: t.fonts.monoRegular,
                  letterSpacing: 1,
                  marginTop: 4,
                }}
              >
                LAST PUNCH · {format(new Date(lastEnded.endTime ?? lastEnded.startTime), "EEE HH:mm").toUpperCase()}
              </PCText>
            ) : null}
          </>
        )}

        {recents.length > 0 ? (
          <View style={{ marginTop: 24 }}>
            <View style={styles.sectionHead}>
              <PCText variant="overline" tone="tertiary">
                Recent
              </PCText>
              <PCText variant="supporting" tone="accent">
                {recents.length}
              </PCText>
            </View>
            <PCCard padding={0}>
              <View style={{ paddingHorizontal: 16 }}>
                {recents.slice(0, 5).map((s, i, arr) => (
                  <PCSessionRow
                    key={s.id}
                    session={s}
                    showDivider={i < arr.slice(0, 5).length - 1}
                  />
                ))}
              </View>
            </PCCard>
          </View>
        ) : null}

        {todayHours > 0 ? (
          <PCText
            variant="supporting"
            tone="tertiary"
            style={{ textAlign: "center", marginTop: 16 }}
          >
            Today · {todayHours}h
          </PCText>
        ) : null}
      </ScrollView>
    </View>
  );
}

const ActiveSessionCard = () => {
  const t = useTokens();
  const router = useRouter();
  const active = useSessionStore((s) => s.active);
  if (!active) return null;

  const started = new Date(active.startTime);

  return (
    <View style={{ gap: 16 }}>
      <PCCard tone="teal" padding={22} radius={t.radii.lg}>
        <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
          <PCText
            variant="overline"
            style={{ color: t.palette.teal600 }}
          >
            Working on
          </PCText>
          <PCChip label="LIVE" tone="live" />
        </View>
        <PCText
          style={{
            fontFamily: t.fonts.monoSemi,
            fontSize: 18,
            color: t.palette.ink900,
            marginTop: 6,
            marginBottom: 16,
          }}
        >
          {active.project}
        </PCText>
        <PCTimer startedAt={active.startTime} size="lg" />
        <PCText
          variant="supporting"
          style={{ color: t.palette.teal600, opacity: 0.85, marginTop: 10 }}
        >
          started {format(started, "H:mm")} · {formatDistanceToNowStrict(started)} in
        </PCText>

        <View style={{ flexDirection: "row", gap: 10, marginTop: 18, alignItems: "center" }}>
          <PCButton
            label="Punch Out"
            variant="rust"
            size="lg"
            fullWidth
            onPress={() => router.push("/punch-out")}
            style={{ flex: 1 }}
          />
          <CircleIcon icon="note-plus-outline" onPress={() => router.push("/log-note")} />
        </View>
      </PCCard>

      {active.notes.length > 0 ? (
        <View>
          <View style={styles.sectionHead}>
            <PCText variant="overline" tone="tertiary">
              Notes this session
            </PCText>
            <PCText variant="supporting" tone="accent">
              {active.notes.length}
            </PCText>
          </View>
          <PCCard tone="inset" padding={14}>
            {active.notes.map((note, i) => (
              <View key={i} style={{ flexDirection: "row", gap: 12, paddingVertical: 6 }}>
                <PCText
                  style={{
                    fontFamily: t.fonts.monoRegular,
                    fontSize: 12,
                    color: t.palette.ink500,
                    width: 44,
                  }}
                >
                  {format(new Date(), "H:mm")}
                </PCText>
                <PCText variant="body" style={{ flex: 1 }}>
                  {note}
                </PCText>
              </View>
            ))}
          </PCCard>
        </View>
      ) : null}
    </View>
  );
};

const CircleIcon = ({ icon, onPress }: { icon: string; onPress: () => void }) => {
  const t = useTokens();
  return (
    <IconButton
      icon={icon}
      size={22}
      mode="contained"
      iconColor={t.palette.ink900}
      containerColor={t.palette.cream50}
      onPress={onPress}
      style={{ width: 56, height: 56, borderRadius: 28, margin: 0 }}
    />
  );
};

const formatWeekRange = (start: Date, end: Date): string => {
  const startMonth = format(start, "MMM").toUpperCase();
  const startDay = format(start, "d");
  const endDay = format(end, "d");
  if (isSameMonth(start, end)) {
    return `${startMonth} ${startDay}–${endDay}`;
  }
  const endMonth = format(end, "MMM").toUpperCase();
  return `${startMonth} ${startDay} – ${endMonth} ${endDay}`;
};

const WeekSummaryCard = () => {
  const t = useTokens();
  const week = useSessionStore((s) => s.week);
  if (!week) return null;

  return (
    <PCCard padding={20}>
      <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <PCText variant="overline" tone="tertiary">
          This week
        </PCText>
        <PCText
          style={{
            fontFamily: t.fonts.monoRegular,
            fontSize: 12,
            color: t.palette.ink500,
          }}
        >
          {formatWeekRange(week.weekStart, week.weekEnd)}
        </PCText>
      </View>
      <View style={{ flexDirection: "row", alignItems: "baseline", marginTop: 10, marginBottom: 18 }}>
        <PCText
          style={{
            fontFamily: t.fonts.display,
            fontSize: 46,
            lineHeight: 52,
            color: t.palette.ink900,
          }}
        >
          {week.totalHours}
        </PCText>
        <PCText variant="title" tone="secondary" style={{ marginLeft: 10 }}>
          hours
        </PCText>
      </View>
      <View style={{ alignItems: "center" }}>
        <PCPunchStrip
          punched={week.punchedDays}
          total={7}
          todayIndex={week.todayIndex}
          width={260}
          height={36}
        />
      </View>
    </PCCard>
  );
};

const styles = StyleSheet.create({
  appbar: {
    height: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  body: { gap: 12 },
  sectionHead: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
});
