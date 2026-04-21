import type { ProjectSyncConfig } from "./project-sync";

export const CONFIG_SCHEME = "punchcard";
export const CONFIG_HOST_PROJECT = "project";

export const encodeProjectURI = (config: ProjectSyncConfig): string => {
  const params = new URLSearchParams();
  params.set("name", config.name);
  if (config.webhookURL) params.set("url", config.webhookURL);
  if (config.sharedSecret) params.set("secret", config.sharedSecret);
  params.set("enabled", config.enabled ? "1" : "0");
  return `${CONFIG_SCHEME}://${CONFIG_HOST_PROJECT}?${params.toString()}`;
};

export type DecodedProject = {
  name: string;
  webhookURL: string | null;
  sharedSecret: string | null;
  enabled: boolean;
};

export const decodeConfigURI = (raw: string): DecodedProject | null => {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return null;
  }

  if (url.protocol !== `${CONFIG_SCHEME}:`) return null;
  const host = url.host || url.pathname.replace(/^\/+/, "").split("/")[0];
  if (host !== CONFIG_HOST_PROJECT) return null;

  const name = url.searchParams.get("name");
  if (!name || !name.trim()) return null;

  const webhookURL = url.searchParams.get("url");
  const sharedSecret = url.searchParams.get("secret");
  const enabled = url.searchParams.get("enabled") !== "0";
  if (webhookURL && !/^https:\/\/.+/i.test(webhookURL)) return null;

  return {
    name: name.trim(),
    webhookURL: webhookURL || null,
    sharedSecret: sharedSecret && sharedSecret.length > 0 ? sharedSecret : null,
    enabled,
  };
};
