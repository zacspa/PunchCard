import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Image, Pressable, ScrollView, StyleSheet, View } from "react-native";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { Snackbar, Switch, TextInput } from "react-native-paper";
import { DatePickerModal, TimePickerModal } from "react-native-paper-dates";
import { format } from "date-fns";
import * as Crypto from "expo-crypto";

import {
  PCButton,
  PCCard,
  PCChip,
  PCFieldButton,
  PCHairline,
  PCProjectDot,
  PCText,
  projectTone,
} from "@/components/pc";
import { useTokens } from "@/lib/theme";
import { listProjects } from "@/lib/db/projects";
import { getExpenseById, insertExpense, updateExpense } from "@/lib/db/expenses";
import { enqueueExpense } from "@/lib/db/expense-queue";
import { useExpenseStore } from "@/lib/state/expense-store";
import { useSessionStore } from "@/lib/state/session-store";
import { persistReceiptImage } from "@/lib/storage/receipts";
import { pushExpenseBestEffort } from "@/lib/sync/expense-dispatcher";
import type { Expense, ExpenseCategory } from "@/lib/models/expense";

const CATEGORIES: { value: ExpenseCategory; label: string }[] = [
  { value: "meals", label: "Meals" },
  { value: "travel", label: "Travel" },
  { value: "software", label: "Software" },
  { value: "supplies", label: "Supplies" },
];

const parseAmount = (raw: string): number | null => {
  const trimmed = raw.replace(/[^0-9.]/g, "");
  if (!trimmed) return null;
  const n = Number(trimmed);
  if (!Number.isFinite(n) || n < 0) return null;
  return Math.round(n * 100);
};

const formatAmountInput = (cents: number | null): string => {
  if (cents === null) return "";
  const whole = Math.floor(cents / 100);
  const frac = cents % 100;
  return `${whole}.${frac.toString().padStart(2, "0")}`;
};

export default function ExpenseNewScreen() {
  const router = useRouter();
  const t = useTokens();
  const params = useLocalSearchParams<{ sourceImageURI?: string; id?: string }>();
  const refresh = useExpenseStore((s) => s.refresh);
  const activeSession = useSessionStore((s) => s.active);

  const editingId = params.id || null;
  const isEdit = editingId !== null;

  const expenseIdRef = useRef<string>(editingId ?? Crypto.randomUUID().toUpperCase());
  const originalRef = useRef<Expense | null>(null);
  const [loaded, setLoaded] = useState(!isEdit);
  const [imagePath, setImagePath] = useState<string | null>(null);
  const [amountText, setAmountText] = useState("");
  const [merchant, setMerchant] = useState("");
  const [capturedAt, setCapturedAt] = useState<Date>(new Date());
  const [category, setCategory] = useState<ExpenseCategory | null>(null);
  const [projects, setProjects] = useState<string[]>([]);
  const [project, setProject] = useState<string | null>(null);
  const [billable, setBillable] = useState(true);
  const [note, setNote] = useState("");

  const [dateOpen, setDateOpen] = useState(false);
  const [timeOpen, setTimeOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Persist the captured image once on mount if we got one from the camera.
  useEffect(() => {
    const source = params.sourceImageURI;
    if (!source || imagePath || isEdit) return;
    try {
      const saved = persistReceiptImage(source, expenseIdRef.current);
      setImagePath(saved);
    } catch {
      setError("Couldn't save the receipt photo.");
    }
  }, [params.sourceImageURI, imagePath, isEdit]);

  // Hydrate from existing row when editing.
  useEffect(() => {
    if (!editingId) return;
    let cancelled = false;
    getExpenseById(editingId).then((row) => {
      if (cancelled || !row) return;
      originalRef.current = row;
      expenseIdRef.current = row.id;
      setImagePath(row.receiptImagePath);
      setAmountText(formatAmountInput(row.amountCents));
      setMerchant(row.merchant);
      setCapturedAt(new Date(row.capturedAt));
      setCategory(row.category);
      setBillable(row.billable);
      setNote(row.note ?? "");
      setProject(row.project);
      setLoaded(true);
    });
    return () => {
      cancelled = true;
    };
  }, [editingId]);

  useEffect(() => {
    listProjects().then((ps) => {
      setProjects(ps);
      if (isEdit) return; // preserved from hydration
      const initial = activeSession?.project ?? (ps.length === 1 ? ps[0] : null);
      if (initial && ps.includes(initial)) setProject(initial);
      else if (ps.length === 1) setProject(ps[0]);
    });
  }, [activeSession, isEdit]);

  const amountCents = useMemo(() => parseAmount(amountText), [amountText]);
  const canSave = loaded && !submitting && project !== null && amountCents !== null && amountCents > 0;

  const buildExpense = (): Expense => {
    const now = new Date().toISOString();
    const base = originalRef.current;
    return {
      id: expenseIdRef.current,
      project: project!,
      merchant: merchant.trim(),
      amountCents: amountCents!,
      currency: "USD",
      capturedAt: capturedAt.toISOString(),
      category,
      billable,
      note: note.trim() || null,
      receiptImagePath: imagePath,
      ocr: base?.ocr ?? null,
      syncState: "queued",
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
      deleted: false,
    };
  };

  const save = async (reopenCapture: boolean) => {
    if (!canSave) return;
    setSubmitting(true);
    const expense = buildExpense();
    try {
      if (isEdit) {
        await updateExpense(expense);
      } else {
        await insertExpense(expense);
      }
      await enqueueExpense(expense.id);
      pushExpenseBestEffort(expense);
      await refresh();
    } catch (e) {
      setSubmitting(false);
      setError("Couldn't save the expense.");
      return;
    }
    if (reopenCapture && !isEdit) {
      expenseIdRef.current = Crypto.randomUUID().toUpperCase();
      setImagePath(null);
      setAmountText("");
      setMerchant("");
      setCapturedAt(new Date());
      setCategory(null);
      setNote("");
      setSubmitting(false);
      router.replace("/expense-capture");
    } else {
      setSubmitting(false);
      router.back();
    }
  };

  const retake = useCallback(() => {
    router.replace("/expense-capture");
  }, [router]);

  const onDateConfirm = useCallback(({ date }: { date: Date | undefined }) => {
    setDateOpen(false);
    if (!date) return;
    setCapturedAt((prev) => {
      const next = new Date(date);
      next.setHours(prev.getHours(), prev.getMinutes(), 0, 0);
      return next;
    });
    setTimeOpen(true);
  }, []);

  const onTimeConfirm = useCallback(
    ({ hours, minutes }: { hours: number; minutes: number }) => {
      setTimeOpen(false);
      setCapturedAt((prev) => {
        const next = new Date(prev);
        next.setHours(hours, minutes, 0, 0);
        return next;
      });
    },
    [],
  );

  return (
    <View style={{ flex: 1, backgroundColor: t.palette.cream50 }}>
      <Stack.Screen options={{ title: isEdit ? "Edit expense" : "New expense" }} />
      <ScrollView
        contentContainerStyle={styles.body}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.hero}>
          <Pressable
            onPress={isEdit ? undefined : retake}
            accessibilityLabel={isEdit ? "Receipt photo" : "Retake receipt"}
          >
            {imagePath ? (
              <Image
                source={{ uri: imagePath }}
                style={[styles.heroThumb, { backgroundColor: t.palette.cream200 }]}
              />
            ) : (
              <View
                style={[
                  styles.heroThumb,
                  {
                    backgroundColor: t.palette.cream100,
                    borderWidth: 1,
                    borderColor: t.palette.cream200,
                    alignItems: "center",
                    justifyContent: "center",
                  },
                ]}
              >
                <PCText tone="tertiary" variant="supporting">
                  {isEdit ? "No photo" : "Retake"}
                </PCText>
              </View>
            )}
          </Pressable>
          <View style={{ flex: 1, marginLeft: 16 }}>
            <PCText variant="overline" tone="tertiary">
              Amount
            </PCText>
            <TextInput
              value={amountText}
              onChangeText={setAmountText}
              keyboardType="decimal-pad"
              mode="flat"
              underlineColor="transparent"
              activeUnderlineColor="transparent"
              placeholder="$0.00"
              style={{
                backgroundColor: "transparent",
                fontFamily: t.fonts.display,
                fontSize: 40,
                paddingHorizontal: 0,
                height: 58,
              }}
              dense
            />
            <PCText variant="supporting" tone="tertiary">
              USD
            </PCText>
          </View>
        </View>

        <PCCard padding={0} style={{ marginTop: 20 }}>
          <View style={styles.fieldRow}>
            <PCText variant="overline" tone="tertiary">
              Merchant
            </PCText>
            <TextInput
              value={merchant}
              onChangeText={setMerchant}
              mode="flat"
              underlineColor="transparent"
              activeUnderlineColor="transparent"
              placeholder="e.g. Café Grumpy"
              style={{ backgroundColor: "transparent", paddingHorizontal: 0, flex: 1, textAlign: "right" }}
              dense
            />
          </View>
          <PCHairline />
          <PCFieldButton
            label={format(capturedAt, "MMM d · h:mm a")}
            onPress={() => setDateOpen(true)}
            style={{ borderRadius: 0, borderWidth: 0, backgroundColor: "transparent" }}
          />
          <PCHairline />
          <View style={[styles.fieldRow, { flexDirection: "column", alignItems: "flex-start", gap: 8 }]}>
            <PCText variant="overline" tone="tertiary">
              Category
            </PCText>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {CATEGORIES.map((c) => (
                <PCChip
                  key={c.value}
                  label={c.label}
                  tone={category === c.value ? "teal" : "neutral"}
                  selected={category === c.value}
                  onPress={() => setCategory(category === c.value ? null : c.value)}
                />
              ))}
            </View>
          </View>
          <PCHairline />
          <View style={[styles.fieldRow, { flexDirection: "row", alignItems: "center" }]}>
            <PCText variant="overline" tone="tertiary">
              Billable
            </PCText>
            <Switch value={billable} onValueChange={setBillable} />
          </View>
        </PCCard>

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
                const selected = project === name;
                return (
                  <Pressable key={name} onPress={() => setProject(name)}>
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
                      <PCProjectDot name={name} tone={projectTone(name)} />
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

        <View style={[styles.sectionHead, { marginTop: 20 }]}>
          <PCText variant="overline" tone="tertiary">
            Note
          </PCText>
        </View>
        <TextInput
          value={note}
          onChangeText={setNote}
          mode="outlined"
          multiline
          numberOfLines={3}
          placeholder="Add a note"
          style={{ backgroundColor: t.palette.cream50 }}
        />

        <View style={{ flexDirection: "row", gap: 10, marginTop: 24 }}>
          {!isEdit ? (
            <PCButton
              label="Save & new"
              variant="outline"
              size="lg"
              onPress={() => save(true)}
              disabled={!canSave}
              style={{ flex: 1 }}
            />
          ) : null}
          <PCButton
            label={isEdit ? "Save changes" : "Save expense"}
            variant="filled"
            size="lg"
            onPress={() => save(false)}
            loading={submitting}
            disabled={!canSave}
            style={{ flex: isEdit ? 1 : 1.2 }}
          />
        </View>
        <PCButton
          label="Cancel"
          variant="ghost"
          size="md"
          fullWidth
          onPress={() => router.back()}
          style={{ marginTop: 10 }}
        />
      </ScrollView>

      <DatePickerModal
        locale="en"
        mode="single"
        visible={dateOpen}
        onDismiss={() => setDateOpen(false)}
        date={capturedAt}
        onConfirm={onDateConfirm}
        validRange={{ endDate: new Date() }}
        saveLabel="Next"
      />
      <TimePickerModal
        locale="en"
        visible={timeOpen}
        onDismiss={() => setTimeOpen(false)}
        onConfirm={onTimeConfirm}
        hours={capturedAt.getHours()}
        minutes={capturedAt.getMinutes()}
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

const styles = StyleSheet.create({
  body: { padding: 20, paddingBottom: 48 },
  hero: { flexDirection: "row", alignItems: "flex-start" },
  heroThumb: {
    width: 96,
    height: 128,
    borderRadius: 10,
  },
  fieldRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 10,
    minHeight: 52,
  },
  sectionHead: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 20,
    marginBottom: 10,
  },
});
