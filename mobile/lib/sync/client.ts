import type { SyncConfig } from "../models/session";

export const REQUEST_TIMEOUT_MS = 5_000;
export const OVERALL_TIMEOUT_MS = 7_000;
export const EXPENSE_TIMEOUT_MS = 20_000;

export type SyncResult =
  | { ok: true; status: number }
  | { ok: false; kind: "not-configured" | "disabled" | "timeout" | "bad-status" | "bad-response" | "network"; status?: number; message: string };

const buildURL = (webhookURL: string, secret: string | null): string => {
  if (!secret) return webhookURL;
  const joiner = webhookURL.includes("?") ? "&" : "?";
  return `${webhookURL}${joiner}secret=${encodeURIComponent(secret)}`;
};

export const postEnvelope = async (
  config: SyncConfig,
  envelope: Record<string, unknown>,
  timeoutMs: number = OVERALL_TIMEOUT_MS,
): Promise<SyncResult> => {
  if (!config.enabled) {
    return { ok: false, kind: "disabled", message: "Sync is disabled in settings." };
  }
  if (!config.webhookURL) {
    return { ok: false, kind: "not-configured", message: "No webhook URL configured." };
  }

  const url = buildURL(config.webhookURL, config.sharedSecret);
  const controller = new AbortController();
  const overallTimer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (config.sharedSecret) headers["X-PunchCard-Secret"] = config.sharedSecret;

    const response = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(envelope),
      signal: controller.signal,
    });

    if (response.status < 200 || response.status >= 300) {
      const body = await response.text().catch(() => "");
      return {
        ok: false,
        kind: "bad-status",
        status: response.status,
        message: `HTTP ${response.status}: ${body.slice(0, 200)}`,
      };
    }

    const text = await response.text();
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return {
        ok: false,
        kind: "bad-response",
        status: response.status,
        message: `Response was not JSON: ${text.slice(0, 120)}`,
      };
    }
    if (typeof parsed === "object" && parsed !== null) {
      const obj = parsed as Record<string, unknown>;
      if (obj.ok === true) return { ok: true, status: response.status };
      if (typeof obj.error === "string") {
        return { ok: false, kind: "bad-response", status: response.status, message: `Server error: ${obj.error}` };
      }
    }
    return {
      ok: false,
      kind: "bad-response",
      status: response.status,
      message: "Response did not include ok:true",
    };
  } catch (err: unknown) {
    if (err instanceof Error && err.name === "AbortError") {
      return { ok: false, kind: "timeout", message: `Timed out after ${timeoutMs}ms` };
    }
    const msg = err instanceof Error ? err.message : String(err);
    return { ok: false, kind: "network", message: msg };
  } finally {
    clearTimeout(overallTimer);
  }
};
