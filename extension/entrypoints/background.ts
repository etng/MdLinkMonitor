import browser from "webextension-polyfill";
import { loadSettings, type ExtensionSettings } from "../lib/storage";

interface CopyResult {
  markdown: string;
  title: string;
  url: string;
  source: string;
}

const SUCCESS_COLOR = "#1f7a45";
const ERROR_COLOR = "#a11d2a";
const NOTICE_COLOR = "#9a5c00";
const OFFSCREEN_DOCUMENT_PATH = "offscreen.html";
const ALL_SITES_PERMISSION = {
  origins: ["<all_urls>"]
};
let offscreenCreationPromise: Promise<void> | null = null;

export default defineBackground(() => {
  browser.action.onClicked.addListener(async (tab) => {
    const tabId = tab.id;
    if (tabId === undefined) {
      return;
    }

    try {
      const settings = await loadSettings();
      const result = await extractPageMarkdown(tabId, settings);
      if (!result) {
        throw new Error("Failed to extract page details");
      }
      await writeMarkdownToClipboard(result.markdown);

      console.info("[mdmonitor-ext] copied", {
        title: result.title,
        url: result.url,
        source: result.source
      });
      await flashBadge(tabId, "OK", SUCCESS_COLOR);
    } catch (error) {
      if (isMissingTabError(error)) {
        console.info("[mdmonitor-ext] tab disappeared before copy completed", {
          tabId
        });
        return;
      }

      if (await handleAccessFailure(error, tab)) {
        await flashBadge(tabId, "AUTH", NOTICE_COLOR);
        return;
      }

      if (await handleClipboardFailure(error, tab)) {
        await flashBadge(tabId, "COPY", NOTICE_COLOR);
        return;
      }

      console.error("[mdmonitor-ext] failed to copy current page", error);
      await flashBadge(tabId, "ERR", ERROR_COLOR);
    }
  });
});

async function handleClipboardFailure(error: unknown, tab: browser.Tabs.Tab): Promise<boolean> {
  const message = error instanceof Error ? error.message : String(error);
  const patterns = [
    "Clipboard write",
    "navigator.clipboard",
    "offscreen document",
    "background document",
    "copy command"
  ];

  if (!patterns.some((pattern) => message.includes(pattern))) {
    return false;
  }

  console.warn("[mdmonitor-ext] clipboard write failed", {
    url: tab.url,
    message
  });
  await openOptionsNotice("clipboard-failed", tab.url);
  return true;
}

async function handleAccessFailure(error: unknown, tab: browser.Tabs.Tab): Promise<boolean> {
  const message = error instanceof Error ? error.message : String(error);
  const supportedOrigin = buildOriginPattern(tab.url);

  if (isRestrictedPageError(message) || (tab.url !== undefined && !supportedOrigin)) {
    console.warn("[mdmonitor-ext] restricted page", {
      url: tab.url,
      message
    });
    await openOptionsNotice("restricted-page", tab.url);
    return true;
  }

  if (!isPermissionError(message)) {
    return false;
  }

  const [allSitesGranted, currentOriginGranted] = await Promise.all([
    browser.permissions.contains(ALL_SITES_PERMISSION),
    supportedOrigin
      ? browser.permissions.contains({
          origins: [supportedOrigin]
        })
      : Promise.resolve(false)
  ]);

  console.warn("[mdmonitor-ext] page access denied", {
    url: tab.url,
    allSitesGranted,
    currentOriginGranted,
    message
  });

  await openOptionsNotice(
    allSitesGranted ? "site-access-blocked" : "permission-denied",
    tab.url,
    allSitesGranted
  );
  return true;
}

function isPermissionError(message: string): boolean {
  const patterns = [
    "Cannot access contents of url",
    "Missing host permission",
    "Cannot access a chrome:// URL",
    "The extensions gallery cannot be scripted",
    "permission",
    "access to the requested host",
    "This page cannot be scripted"
  ];

  return patterns.some((pattern) => message.toLowerCase().includes(pattern.toLowerCase()));
}

function isRestrictedPageError(message: string): boolean {
  const patterns = [
    "chrome://",
    "edge://",
    "about:",
    "The extensions gallery cannot be scripted",
    "This page cannot be scripted"
  ];

  return patterns.some((pattern) => message.includes(pattern));
}

function isMissingTabError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();
  const patterns = [
    "no tab with id",
    "invalid tab id",
    "the tab was closed",
    "tab not found"
  ];

  return patterns.some((pattern) => lower.includes(pattern));
}

function buildOriginPattern(rawURL: string | undefined): string | null {
  if (!rawURL) {
    return null;
  }

  try {
    const url = new URL(rawURL);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return null;
    }

    return `${url.protocol}//${url.host}/*`;
  } catch {
    return null;
  }
}

async function openOptionsNotice(reason: string, rawURL?: string, allSitesGranted = false): Promise<void> {
  const url = new URL(browser.runtime.getURL("options.html"));
  url.searchParams.set("notice", reason);
  if (rawURL) {
    url.searchParams.set("page", rawURL);
  }
  if (allSitesGranted) {
    url.searchParams.set("all-sites", "granted");
  }

  await browser.tabs.create({ url: url.toString() });
}

async function extractPageMarkdown(tabId: number, settings: ExtensionSettings): Promise<CopyResult | undefined> {
  if (browser.scripting?.executeScript) {
    const [injection] = await browser.scripting.executeScript({
      target: { tabId },
      func: extractCurrentPageAsMarkdown,
      args: [settings]
    });
    return injection.result as CopyResult | undefined;
  }

  const [result] = await browser.tabs.executeScript(tabId, {
    code: `(${extractCurrentPageAsMarkdown.toString()})(${JSON.stringify(settings)})`
  });
  return result as CopyResult | undefined;
}

async function writeMarkdownToClipboard(markdown: string): Promise<void> {
  if (browser.offscreen?.createDocument) {
    await ensureOffscreenDocument();
    const response = (await browser.runtime.sendMessage({
      target: "offscreen",
      type: "copy-text",
      text: markdown
    })) as { ok?: boolean; error?: string } | undefined;

    if (!response?.ok) {
      throw new Error(response?.error ?? "Clipboard write failed in offscreen document");
    }
    return;
  }

  if (globalThis.navigator?.clipboard?.writeText) {
    await globalThis.navigator.clipboard.writeText(markdown);
    return;
  }

  if (typeof document !== "undefined") {
    const textArea = document.createElement("textarea");
    textArea.value = markdown;
    textArea.style.position = "fixed";
    textArea.style.top = "0";
    textArea.style.left = "-9999px";
    textArea.style.opacity = "0";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    textArea.setSelectionRange(0, textArea.value.length);

    try {
      if (!document.execCommand("copy")) {
        throw new Error("Clipboard write failed in background document");
      }
      return;
    } finally {
      textArea.remove();
    }
  }

  throw new Error("Clipboard write is unavailable in this extension context");
}

async function ensureOffscreenDocument(): Promise<void> {
  if (!browser.offscreen?.createDocument) {
    return;
  }

  const offscreenURL = browser.runtime.getURL(OFFSCREEN_DOCUMENT_PATH);
  const runtimeWithContexts = browser.runtime as typeof browser.runtime & {
    getContexts?: (filter: {
      contextTypes?: string[];
      documentUrls?: string[];
    }) => Promise<Array<unknown>>;
  };

  if (runtimeWithContexts.getContexts) {
    const contexts = await runtimeWithContexts.getContexts({
      contextTypes: ["OFFSCREEN_DOCUMENT"],
      documentUrls: [offscreenURL]
    });
    if (contexts.length > 0) {
      return;
    }
  }

  if (!offscreenCreationPromise) {
    offscreenCreationPromise = browser.offscreen
      .createDocument({
        url: OFFSCREEN_DOCUMENT_PATH,
        reasons: ["CLIPBOARD"],
        justification: "Copy Markdown links without using the page clipboard permission prompt"
      })
      .catch((error) => {
        const message = error instanceof Error ? error.message : String(error);
        if (!message.toLowerCase().includes("exists")) {
          throw error;
        }
      })
      .finally(() => {
        offscreenCreationPromise = null;
      });
  }

  await offscreenCreationPromise;
}

async function flashBadge(tabId: number, text: string, color: string): Promise<void> {
  try {
    await browser.action.setBadgeBackgroundColor({ tabId, color });
    await browser.action.setBadgeText({ tabId, text });
  } catch (error) {
    if (isMissingTabError(error)) {
      return;
    }
    throw error;
  }

  setTimeout(() => {
    void browser.action.setBadgeText({ tabId, text: "" }).catch((error) => {
      if (!isMissingTabError(error)) {
        console.error("[mdmonitor-ext] failed to clear badge", error);
      }
    });
  }, 1200);
}

function extractCurrentPageAsMarkdown(settings: ExtensionSettings): CopyResult {
  function normalizeText(value: string): string {
    return value.replace(/\s+/g, " ").trim();
  }

  function currentURLWithoutScheme(parsedURL: URL): string {
    return `${parsedURL.hostname}${parsedURL.pathname}${parsedURL.search}${parsedURL.hash}`;
  }

  function safelyParseURL(value: string): URL | null {
    try {
      return new URL(value);
    } catch {
      return null;
    }
  }

  function isMeaningfulTitle(value: string, parsedURL: URL | null): boolean {
    if (value.length < 4) {
      return false;
    }

    if (!parsedURL) {
      return true;
    }

    const lower = value.toLowerCase();
    if (lower === parsedURL.hostname.toLowerCase()) {
      return false;
    }

    if (lower === currentURLWithoutScheme(parsedURL).toLowerCase()) {
      return false;
    }

    return true;
  }

  function collectHeadingCandidates(): Array<{ value: string; source: string }> {
    const selectors = [
      { selector: "main h1, article h1, [role='main'] h1, h1", source: "heading.h1" },
      { selector: "main h2, article h2, [role='main'] h2, h2", source: "heading.h2" },
      { selector: "main h3, article h3, [role='main'] h3, h3", source: "heading.h3" }
    ];

    return selectors.flatMap(({ selector, source }) =>
      Array.from(document.querySelectorAll<HTMLElement>(selector))
        .map((element) => ({
          value: normalizeText(element.innerText || element.textContent || ""),
          source
        }))
        .filter((entry) => entry.value.length > 0)
    );
  }

  function buildPathFallback(parsedURL: URL | null): string {
    if (!parsedURL) {
      return "";
    }

    const segments = parsedURL.pathname
      .split("/")
      .filter(Boolean)
      .map((segment) => {
        try {
          return decodeURIComponent(segment);
        } catch {
          return segment;
        }
      })
      .map((segment) => segment.replace(/[-_]+/g, " ").trim())
      .filter((segment) => segment.length >= 3 && segment.toLowerCase() !== "index.html");

    if (segments.length === 0) {
      return "";
    }

    return segments[segments.length - 1];
  }

  function pickTitle(currentURL: string): { value: string; source: string } {
    const candidates = [
      { value: normalizeText(document.title), source: "document.title" },
      ...collectHeadingCandidates()
    ];

    const parsedURL = safelyParseURL(currentURL);
    for (const candidate of candidates) {
      if (isMeaningfulTitle(candidate.value, parsedURL)) {
        return candidate;
      }
    }

    const pathFallback = buildPathFallback(parsedURL);
    if (pathFallback.length > 0) {
      return { value: pathFallback, source: "url.path" };
    }

    return {
      value: parsedURL?.hostname ?? "Untitled",
      source: "url.host"
    };
  }

  function escapeMarkdownText(value: string): string {
    return value
      .replace(/\\/g, "\\\\")
      .replace(/\[/g, "\\[")
      .replace(/\]/g, "\\]")
      .replace(/\r?\n/g, " ")
      .trim();
  }

  function buildMarkdown(title: string, currentURL: string): string {
    const prefix = settings.prefixEnabled ? settings.prefixText : "";
    const escapedTitle = escapeMarkdownText(title);
    return `${prefix}[${escapedTitle}](${currentURL})`;
  }

  const currentURL = window.location.href;
  const titleCandidate = pickTitle(currentURL);
  const markdown = buildMarkdown(titleCandidate.value, currentURL);

  return {
    markdown,
    title: titleCandidate.value,
    url: currentURL,
    source: titleCandidate.source
  };
}
