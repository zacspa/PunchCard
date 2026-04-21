import { getProjectSyncConfig } from "../config/project-sync";
import { getSessionById } from "../db/sessions";
import { dequeue, enqueue, listQueued } from "../db/sync-queue";
import type { Session } from "../models/session";
import { buildUpsertEnvelope } from "./payload";
import { postEnvelope, type SyncResult } from "./client";

export const pushSession = async (session: Session): Promise<SyncResult> => {
  const config = await getProjectSyncConfig(session.project);
  if (!config || !config.enabled || !config.webhookURL) {
    await enqueue(session.id, `no sync for project '${session.project}'`);
    return {
      ok: false,
      kind: !config?.enabled ? "disabled" : "not-configured",
      message: `Sync isn't configured for project '${session.project}'.`,
    };
  }
  const result = await postEnvelope(
    {
      webhookURL: config.webhookURL,
      sharedSecret: config.sharedSecret,
      enabled: true,
    },
    buildUpsertEnvelope([session]),
  );
  if (result.ok) {
    await dequeue(session.id);
  } else {
    await enqueue(session.id, result.message);
  }
  return result;
};

export const pushBestEffort = (session: Session): void => {
  pushSession(session).catch(() => {});
};

let activeDrain: Promise<{ drained: number; remaining: number }> | null = null;

export const drainQueue = async (): Promise<{ drained: number; remaining: number }> => {
  if (activeDrain) return activeDrain;
  activeDrain = (async () => {
    try {
      const ids = await listQueued();
      let drained = 0;
      for (const id of ids) {
        const s = await getSessionById(id);
        if (!s) {
          await dequeue(id);
          continue;
        }
        const r = await pushSession(s);
        if (r.ok) drained++;
      }
      return { drained, remaining: (await listQueued()).length };
    } finally {
      activeDrain = null;
    }
  })();
  return activeDrain;
};
