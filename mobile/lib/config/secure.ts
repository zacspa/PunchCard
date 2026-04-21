import * as SecureStore from "expo-secure-store";
import { listProjectConfigs, setProjectSync } from "./project-sync";

const LEGACY_WEBHOOK_KEY = "punchcard.webhookURL";
const LEGACY_SECRET_KEY = "punchcard.sharedSecret";
const LEGACY_ENABLED_KEY = "punchcard.syncEnabled";
const MIGRATION_FLAG_KEY = "punchcard.migration.per_project_sync";

/**
 * One-time migration: copy the old global webhook/secret into every
 * existing project that doesn't yet have its own webhook configured, then
 * clear the legacy SecureStore keys. No-op after the first successful run.
 *
 * Safety rules (all required to avoid data loss):
 *   1. Never overwrite a project that already has a webhook set.
 *   2. If there are no projects yet, leave the legacy keys in place so the
 *      migration can fire next time a project is added.
 *   3. Only mark the migration complete when the legacy keys are confirmed
 *      gone (or were never there).
 */
export const migrateGlobalSyncToProjects = async (): Promise<void> => {
  const flag = await SecureStore.getItemAsync(MIGRATION_FLAG_KEY);
  if (flag === "done") return;

  const [webhookURL, sharedSecret, enabledRaw] = await Promise.all([
    SecureStore.getItemAsync(LEGACY_WEBHOOK_KEY),
    SecureStore.getItemAsync(LEGACY_SECRET_KEY),
    SecureStore.getItemAsync(LEGACY_ENABLED_KEY),
  ]);

  if (!webhookURL) {
    // Nothing to migrate; mark done so we don't keep checking.
    await SecureStore.setItemAsync(MIGRATION_FLAG_KEY, "done");
    return;
  }

  const configs = await listProjectConfigs();
  if (configs.length === 0) {
    // Preserve legacy values until the user adds a project; try again later.
    return;
  }

  const enabled = enabledRaw === "true";
  let applied = 0;
  for (const c of configs) {
    if (c.webhookURL) continue; // don't clobber existing per-project config
    await setProjectSync(c.name, {
      webhookURL,
      sharedSecret: sharedSecret || null,
      enabled,
    });
    applied++;
  }

  if (applied === 0) {
    // Every project already had a config; safe to drop legacy keys.
    await clearLegacyAndMarkDone();
    return;
  }

  await clearLegacyAndMarkDone();
};

const clearLegacyAndMarkDone = async () => {
  await Promise.all([
    SecureStore.deleteItemAsync(LEGACY_WEBHOOK_KEY),
    SecureStore.deleteItemAsync(LEGACY_SECRET_KEY),
    SecureStore.deleteItemAsync(LEGACY_ENABLED_KEY),
  ]);
  await SecureStore.setItemAsync(MIGRATION_FLAG_KEY, "done");
};
