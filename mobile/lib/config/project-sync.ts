import * as SecureStore from "expo-secure-store";
import { asc, eq } from "drizzle-orm";
import { db } from "../db/client";
import { projects } from "../db/schema";

export type ProjectSyncConfig = {
  name: string;
  webhookURL: string | null;
  sharedSecret: string | null;
  enabled: boolean;
};

// SecureStore keys are limited to alphanumerics, ._-  on iOS. Sanitize project
// names before using them as key suffixes; keep a stable one-way mapping.
const secretKey = (projectName: string): string => {
  const safe = projectName.replace(/[^A-Za-z0-9._-]/g, "_");
  return `punchcard.secret.${safe}`;
};

export const getProjectSyncConfig = async (
  name: string,
): Promise<ProjectSyncConfig | null> => {
  const rows = await db
    .select()
    .from(projects)
    .where(eq(projects.name, name))
    .limit(1);
  if (!rows.length) return null;

  const secret = await SecureStore.getItemAsync(secretKey(name));
  return {
    name,
    webhookURL: rows[0].webhookURL ?? null,
    sharedSecret: secret || null,
    enabled: rows[0].syncEnabled,
  };
};

export const setProjectSync = async (
  name: string,
  patch: { webhookURL?: string | null; sharedSecret?: string | null; enabled?: boolean },
): Promise<void> => {
  if (patch.webhookURL !== undefined || patch.enabled !== undefined) {
    const updates: { webhookURL?: string | null; syncEnabled?: boolean } = {};
    if (patch.webhookURL !== undefined) {
      updates.webhookURL = patch.webhookURL?.trim() || null;
    }
    if (patch.enabled !== undefined) {
      updates.syncEnabled = patch.enabled;
    }
    await db.update(projects).set(updates).where(eq(projects.name, name));
  }

  if (patch.sharedSecret !== undefined) {
    const key = secretKey(name);
    if (patch.sharedSecret && patch.sharedSecret.trim()) {
      await SecureStore.setItemAsync(key, patch.sharedSecret.trim());
    } else {
      await SecureStore.deleteItemAsync(key);
    }
  }
};

export const listProjectConfigs = async (): Promise<ProjectSyncConfig[]> => {
  const rows = await db.select().from(projects).orderBy(asc(projects.name));
  const out: ProjectSyncConfig[] = [];
  for (const row of rows) {
    const secret = await SecureStore.getItemAsync(secretKey(row.name));
    out.push({
      name: row.name,
      webhookURL: row.webhookURL ?? null,
      sharedSecret: secret || null,
      enabled: row.syncEnabled,
    });
  }
  return out;
};

export const deleteProjectSync = async (name: string): Promise<void> => {
  await SecureStore.deleteItemAsync(secretKey(name));
};
