import { useCallback, useEffect, useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import { HelperText, SegmentedButtons, Snackbar, TextInput } from "react-native-paper";
import { DatePickerModal, TimePickerModal } from "react-native-paper-dates";
import { format, isSameDay } from "date-fns";
import * as Crypto from "expo-crypto";

import {
  PCButton,
  PCCard,
  PCChip,
  PCFieldButton,
  PCHairline,
  PCProjectDot,
  PCStampCard,
  PCText,
  projectTone,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { getActiveSession, insertSession } from "@/lib/db/sessions";
import { listProjects } from "@/lib/db/projects";
import { useSessionStore } from "@/lib/state/session-store";
import { pushBestEffort } from "@/lib/sync/dispatcher";
import { hoursBetween } from "@/lib/models/session";
import { minutesAgo, parseAtTime } from "@/lib/time/parse";
import type { Session } from "@/lib/models/session";

type Mode = "now" | "past";

type Chosen =
  | { kind: "now" }
  | { kind: "ago"; minutes: number }
  | { kind: "at"; label: string; date: Date };

type PickerTarget = "now-start" | "past-start" | "past-end";

const chipOptions: { label: string; value: Chosen }[] = [
  { label: "Now", value: { kind: "now" } },
  { label: "15m ago", value: { kind: "ago", minutes: 15 } },
  { label: "30m ago", value: { kind: "ago", minutes: 30 } },
  { label: "1h ago", value: { kind: "ago", minutes: 60 } },
];

const formatPickedDate = (d: Date): string =>
  isSameDay(d, new Date()) ? format(d, "h:mm a") : format(d, "MMM d · h:mm a");

export default function PunchInScreen() {
  const router = useRouter();
  const t = useTokens();
  const refresh = useSessionStore((s) => s.refresh);

  const [mode, setMode] = useState<Mode>("now");
  const [projects, setProjects] = useState<string[]>([]);
  const [selectedProject, setSelectedProject] = useState<string | null>(null);

  const [chosen, setChosen] = useState<Chosen>({ kind: "now" });
  const [customTime, setCustomTime] = useState("");
  const [customError, setCustomError] = useState<string | null>(null);

  const [pastStart, setPastStart] = useState<Date | null>(null);
  const [pastEnd, setPastEnd] = useState<Date | null>(null);
  const [pastSummary, setPastSummary] = useState("");

  const [pickerTarget, setPickerTarget] = useState<PickerTarget | null>(null);
  const [dateOpen, setDateOpen] = useState(false);
  const [pickedDate, setPickedDate] = useState<Date | null>(null);
  const [timeOpen, setTimeOpen] = useState(false);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listProjects().then((ps) => {
      setProjects(ps);
      if (ps.length === 1) setSelectedProject(ps[0]);
    });
  }, []);

  const resolveNowStart = useCallback((): Date | null => {
    if (chosen.kind === "now") return new Date();
    if (chosen.kind === "ago") return minutesAgo(chosen.minutes);
    if (chosen.kind === "at") return chosen.date;
    return null;
  }, [chosen]);

  const applyCustom = () => {
    const d = parseAtTime(customTime);
    if (!d) {
      setCustomError("Enter a past time like 9:15, 8am, or 14:30.");
      return;
    }
    setCustomError(null);
    setChosen({ kind: "at", label: customTime.trim(), date: d });
  };

  const openPicker = (target: PickerTarget) => {
    setPickerTarget(target);
    setDateOpen(true);
  };

  const onDateConfirm = useCallback(({ date }: { date: Date | undefined }) => {
    setDateOpen(false);
    if (!date) {
      setPickerTarget(null);
      return;
    }
    setPickedDate(date);
    setTimeOpen(true);
  }, []);

  const onTimeConfirm = useCallback(
    ({ hours, minutes }: { hours: number; minutes: number }) => {
      setTimeOpen(false);
      const base = pickedDate ?? new Date();
      const combined = new Date(base);
      combined.setHours(hours, minutes, 0, 0);
      const target = pickerTarget;
      setPickedDate(null);
      setPickerTarget(null);

      if (target === "now-start" || target === "past-end") {
        if (combined.getTime() > Date.now()) {
          setError("That time is in the future.");
          return;
        }
      }

      if (target === "now-start") {
        setChosen({ kind: "at", label: formatPickedDate(combined), date: combined });
      } else if (target === "past-start") {
        setPastStart(combined);
      } else if (target === "past-end") {
        setPastEnd(combined);
      }
    },
    [pickedDate, pickerTarget],
  );

  const dismissDate = () => {
    setDateOpen(false);
    setPickerTarget(null);
  };

  const dismissTime = () => {
    setTimeOpen(false);
    setPickedDate(null);
    setPickerTarget(null);
  };

  const initialPickerDate = useMemo((): Date => {
    if (pickerTarget === "past-start" && pastStart) return pastStart;
    if (pickerTarget === "past-end" && pastEnd) return pastEnd;
    if (pickerTarget === "past-end" && pastStart) return pastStart;
    if (pickerTarget === "now-start" && chosen.kind === "at") return chosen.date;
    return new Date();
  }, [pickerTarget, pastStart, pastEnd, chosen]);

  const submitNow = async () => {
    if (!selectedProject) return setError("Pick a project.");
    const active = await getActiveSession();
    if (active) return setError(`Already active: ${active.project}. Punch out first.`);
    const start = resolveNowStart();
    if (!start) return setError("Pick a start time.");

    setSubmitting(true);
    const session: Session = {
      id: Crypto.randomUUID().toUpperCase(),
      project: selectedProject,
      startTime: start.toISOString(),
      endTime: null,
      notes: [],
      summary: null,
      commits: [],
      deleted: false,
    };
    await insertSession(session);
    pushBestEffort(session);
    await refresh();
    setSubmitting(false);
    router.back();
  };

  const submitPast = async () => {
    if (!selectedProject) return setError("Pick a project.");
    if (!pastStart || !pastEnd) return setError("Pick a start and end time.");
    if (pastEnd.getTime() <= pastStart.getTime()) return setError("End must be after start.");
    if (pastEnd.getTime() > Date.now()) return setError("End time is in the future.");

    setSubmitting(true);
    const session: Session = {
      id: Crypto.randomUUID().toUpperCase(),
      project: selectedProject,
      startTime: pastStart.toISOString(),
      endTime: pastEnd.toISOString(),
      notes: [],
      summary: pastSummary.trim() || null,
      commits: [],
      deleted: false,
    };
    await insertSession(session);
    pushBestEffort(session);
    await refresh();
    setSubmitting(false);
    router.back();
  };

  const submit = () => {
    setError(null);
    if (mode === "now") submitNow();
    else submitPast();
  };

  const previewStart = mode === "now" ? resolveNowStart() : null;
  const pastHours =
    pastStart && pastEnd && pastEnd.getTime() > pastStart.getTime()
      ? hoursBetween(pastStart.toISOString(), pastEnd.toISOString())
      : null;
  const submitDisabled =
    submitting ||
    !selectedProject ||
    (mode === "past" && (!pastStart || !pastEnd));

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
        <SegmentedButtons
          value={mode}
          onValueChange={(v) => setMode(v as Mode)}
          buttons={[
            { value: "now", label: "Now", icon: "clock-outline" },
            { value: "past", label: "Past session", icon: "history" },
          ]}
          style={{ marginBottom: 20 }}
        />

        <View style={styles.sectionHead}>
          <PCText variant="overline" tone="tertiary">
            Project
          </PCText>
          {projects.length > 0 ? (
            <Pressable onPress={() => router.push("/settings/projects")}>
              <PCText variant="supporting" tone="accent">
                New ›
              </PCText>
            </Pressable>
          ) : null}
        </View>

        {projects.length === 0 ? (
          <PCCard tone="outline" padding={18}>
            <PCText variant="body" tone="secondary">
              No projects yet.
            </PCText>
            <PCButton
              label="Add a project"
              variant="outline"
              size="sm"
              style={{ marginTop: 12 }}
              onPress={() => router.push("/settings/projects")}
            />
          </PCCard>
        ) : (
          <PCCard padding={0}>
            <View style={{ paddingHorizontal: 16 }}>
              {projects.map((name, i) => {
                const selected = selectedProject === name;
                const tone = projectTone(name);
                return (
                  <Pressable key={name} onPress={() => setSelectedProject(name)}>
                    <View
                      style={{
                        flexDirection: "row",
                        alignItems: "center",
                        paddingVertical: 12,
                        gap: 12,
                        marginHorizontal: -16,
                        paddingHorizontal: 16,
                        backgroundColor: selected ? t.palette.teal50 : "transparent",
                      }}
                    >
                      <PCProjectDot name={name} tone={tone} />
                      <PCText
                        style={{
                          fontFamily: t.fonts.monoSemi,
                          fontSize: 14,
                          color: t.palette.ink900,
                          flex: 1,
                        }}
                      >
                        {name}
                      </PCText>
                      {selected ? <CheckCircle /> : null}
                    </View>
                    {i < projects.length - 1 ? <PCHairline /> : null}
                  </Pressable>
                );
              })}
            </View>
          </PCCard>
        )}

        {mode === "now" ? (
          <>
            <View style={[styles.sectionHead, { marginTop: 20 }]}>
              <PCText variant="overline" tone="tertiary">
                Start time
              </PCText>
            </View>
            <View style={styles.chipRow}>
              {chipOptions.map(({ label, value }) => {
                const selected =
                  chosen.kind === value.kind &&
                  (value.kind !== "ago" || (chosen.kind === "ago" && chosen.minutes === value.minutes));
                return (
                  <PCChip
                    key={label}
                    label={label}
                    tone={selected ? "teal" : "neutral"}
                    selected={selected}
                    onPress={() => setChosen(value)}
                  />
                );
              })}
              <PCChip
                label={chosen.kind === "at" ? chosen.label : "Pick date…"}
                tone={chosen.kind === "at" ? "teal" : "neutral"}
                selected={chosen.kind === "at"}
                onPress={() => openPicker("now-start")}
              />
            </View>

            <TextInput
              label="Or enter a past time (e.g. 9:15)"
              mode="outlined"
              value={customTime}
              onChangeText={(v) => {
                setCustomTime(v);
                setCustomError(null);
              }}
              onSubmitEditing={applyCustom}
              autoCapitalize="none"
              dense
              style={{ marginTop: 10, backgroundColor: t.palette.cream50 }}
              right={
                <TextInput.Icon icon="check" onPress={applyCustom} disabled={!customTime.trim()} />
              }
            />
            <HelperText type="error" visible={!!customError}>
              {customError ?? " "}
            </HelperText>

            {selectedProject && previewStart ? (
              <>
                <View style={[styles.sectionHead, { marginTop: 20 }]}>
                  <PCText variant="overline" tone="tertiary">
                    Stamp will read
                  </PCText>
                </View>
                <PCStampCard action="in" time={previewStart} project={selectedProject} />
              </>
            ) : null}
          </>
        ) : (
          <>
            <View style={[styles.sectionHead, { marginTop: 20 }]}>
              <PCText variant="overline" tone="tertiary">
                Start
              </PCText>
            </View>
            <PCFieldButton
              label={pastStart ? formatPickedDate(pastStart) : "Pick start date & time"}
              placeholder={!pastStart}
              leading={<DotIcon />}
              onPress={() => openPicker("past-start")}
            />

            <View style={[styles.sectionHead, { marginTop: 16 }]}>
              <PCText variant="overline" tone="tertiary">
                End
              </PCText>
            </View>
            <PCFieldButton
              label={pastEnd ? formatPickedDate(pastEnd) : "Pick end date & time"}
              placeholder={!pastEnd}
              leading={<DotIcon />}
              onPress={() => openPicker("past-end")}
            />

            {pastHours !== null ? (
              <PCText variant="supporting" tone="tertiary" style={{ marginTop: 8 }}>
                Duration: {pastHours}h
              </PCText>
            ) : null}

            <TextInput
              label="Summary"
              mode="outlined"
              value={pastSummary}
              onChangeText={setPastSummary}
              multiline
              numberOfLines={4}
              style={{ marginTop: 16, backgroundColor: t.palette.cream50 }}
            />
          </>
        )}

        <View style={{ marginTop: 28, gap: 10 }}>
          <PCButton
            label={mode === "now" ? (selectedProject ? `Punch In · ${selectedProject}` : "Punch In") : "Log Session"}
            variant="rust"
            size="xl"
            fullWidth
            loading={submitting}
            disabled={submitDisabled}
            onPress={submit}
          />
          <PCButton
            label="Cancel"
            variant="ghost"
            size="md"
            fullWidth
            onPress={() => router.back()}
          />
        </View>
      </ScrollView>

      <DatePickerModal
        locale="en"
        mode="single"
        visible={dateOpen}
        onDismiss={dismissDate}
        date={initialPickerDate}
        onConfirm={onDateConfirm}
        validRange={{ endDate: new Date() }}
        saveLabel="Next"
      />

      <TimePickerModal
        locale="en"
        visible={timeOpen}
        onDismiss={dismissTime}
        onConfirm={onTimeConfirm}
        hours={(pickedDate ?? initialPickerDate).getHours()}
        minutes={(pickedDate ?? initialPickerDate).getMinutes()}
      />

      <Snackbar visible={error !== null} onDismiss={() => setError(null)} duration={4000}>
        {error ?? ""}
      </Snackbar>
    </View>
  );
}

const CheckCircle = () => {
  const t = useTokens();
  return (
    <View
      style={{
        width: 20,
        height: 20,
        borderRadius: 10,
        backgroundColor: t.palette.teal600,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <PCText style={{ color: t.palette.cream50, fontSize: 12, fontFamily: "Inter_700Bold" }}>
        ✓
      </PCText>
    </View>
  );
};

const DotIcon = () => {
  const t = useTokens();
  return (
    <View
      style={{
        width: 8,
        height: 8,
        borderRadius: 4,
        backgroundColor: t.palette.ink900,
      }}
    />
  );
};

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 40 },
  sectionHead: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 10,
  },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
