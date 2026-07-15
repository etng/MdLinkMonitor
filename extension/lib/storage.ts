import browser from "webextension-polyfill";

export interface ExtensionSettings {
  prefixEnabled: boolean;
  prefixText: string;
}

export const DEFAULT_SETTINGS: ExtensionSettings = {
  prefixEnabled: true,
  prefixText: "* [ ] "
};

const STORAGE_KEY = "mdmonitor-settings";

function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function normalizeString(value: unknown, fallback: string): string {
  if (typeof value !== "string") {
    return fallback;
  }

  return value;
}

export function normalizeSettings(value: Partial<ExtensionSettings> | undefined): ExtensionSettings {
  return {
    prefixEnabled: normalizeBoolean(value?.prefixEnabled, DEFAULT_SETTINGS.prefixEnabled),
    prefixText: normalizeString(value?.prefixText, DEFAULT_SETTINGS.prefixText)
  };
}

export async function loadSettings(): Promise<ExtensionSettings> {
  const stored = await browser.storage.local.get(STORAGE_KEY);
  return normalizeSettings(stored[STORAGE_KEY] as Partial<ExtensionSettings> | undefined);
}

export async function saveSettings(settings: ExtensionSettings): Promise<void> {
  await browser.storage.local.set({
    [STORAGE_KEY]: normalizeSettings(settings)
  });
}
