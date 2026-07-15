import "./styles.css";

import browser from "webextension-polyfill";
import { loadSettings, saveSettings } from "../../lib/storage";

const prefixEnabledInput = document.querySelector<HTMLInputElement>("#prefix-enabled");
const prefixTextInput = document.querySelector<HTMLInputElement>("#prefix-text");
const saveButton = document.querySelector<HTMLButtonElement>("#save-button");
const saveStatus = document.querySelector<HTMLSpanElement>("#save-status");
const hostPermissionStatus = document.querySelector<HTMLSpanElement>("#host-permission-status");
const grantHostAccessButton = document.querySelector<HTMLButtonElement>("#grant-host-access-button");
const noticeBanner = document.querySelector<HTMLElement>("#notice-banner");
const noticeTitle = document.querySelector<HTMLElement>("#notice-title");
const noticeText = document.querySelector<HTMLElement>("#notice-text");

const ALL_SITES_PERMISSION = {
  origins: ["<all_urls>"]
};

if (
  !prefixEnabledInput ||
  !prefixTextInput ||
  !saveButton ||
  !saveStatus ||
  !hostPermissionStatus ||
  !grantHostAccessButton ||
  !noticeBanner ||
  !noticeTitle ||
  !noticeText
) {
  throw new Error("Options page failed to initialize");
}

void initialize();

saveButton.addEventListener("click", () => {
  void handleSave();
});

grantHostAccessButton.addEventListener("click", () => {
  void handleGrantHostAccess();
});

async function initialize(): Promise<void> {
  const [settings] = await Promise.all([loadSettings(), refreshHostPermissionState()]);
  prefixEnabledInput.checked = settings.prefixEnabled;
  prefixTextInput.value = settings.prefixText;
  saveStatus.textContent = "";
  renderNotice();
}

async function handleSave(): Promise<void> {
  saveButton.disabled = true;
  saveStatus.textContent = "保存中...";

  try {
    await saveSettings({
      prefixEnabled: prefixEnabledInput.checked,
      prefixText: prefixTextInput.value
    });
    saveStatus.textContent = "已保存";
  } catch (error) {
    console.error("[mdmonitor-ext] failed to save settings", error);
    saveStatus.textContent = "保存失败";
  } finally {
    saveButton.disabled = false;
  }
}

async function handleGrantHostAccess(): Promise<void> {
  grantHostAccessButton.disabled = true;
  hostPermissionStatus.textContent = "授权中...";
  hostPermissionStatus.dataset.state = "pending";

  try {
    const granted = await browser.permissions.request(ALL_SITES_PERMISSION);
    await refreshHostPermissionState();

    if (!granted) {
      saveStatus.textContent = "用户取消了授权";
    } else {
      saveStatus.textContent = "已授权所有网站";
    }
  } catch (error) {
    console.error("[mdmonitor-ext] failed to request host access", error);
    hostPermissionStatus.textContent = "授权失败";
    hostPermissionStatus.dataset.state = "error";
    saveStatus.textContent = "网站权限申请失败";
    grantHostAccessButton.disabled = false;
  }
}

async function refreshHostPermissionState(): Promise<void> {
  try {
    const granted = await browser.permissions.contains(ALL_SITES_PERMISSION);
    hostPermissionStatus.textContent = granted ? "已授权所有网站" : "按点击临时授权";
    hostPermissionStatus.dataset.state = granted ? "granted" : "limited";
    grantHostAccessButton.disabled = granted;
    grantHostAccessButton.textContent = granted ? "已授权" : "授权所有网站";
  } catch (error) {
    console.error("[mdmonitor-ext] failed to inspect host access", error);
    hostPermissionStatus.textContent = "状态不可用";
    hostPermissionStatus.dataset.state = "error";
    grantHostAccessButton.disabled = false;
    grantHostAccessButton.textContent = "重试授权";
  }
}

function renderNotice(): void {
  const params = new URLSearchParams(window.location.search);
  const notice = params.get("notice");
  if (!notice) {
    noticeBanner.hidden = true;
    return;
  }

  const page = params.get("page");
  const pageLabel = page ? `当前页面：${truncate(page, 88)}` : "当前页面未提供";
  noticeBanner.hidden = false;

  switch (notice) {
    case "permission-denied":
      noticeTitle.textContent = "当前站点还没有授权";
      noticeText.textContent = `${pageLabel}。如果你关闭了浏览器权限提示，浏览器会按未授权处理。你可以在这里点“授权所有网站”，或者在浏览器扩展详情里把 Site access 改成允许所有网站。`;
      break;
    case "site-access-blocked":
      noticeTitle.textContent = "浏览器仍在拦当前站点";
      noticeText.textContent = `${pageLabel}。扩展已经拿到全站权限，但浏览器的站点访问策略仍可能被设成“按点击”或当前站点未放行。请到扩展详情里把 Site access 调整为 On all sites。`;
      break;
    case "restricted-page":
      noticeTitle.textContent = "这个页面本来就不能注入";
      noticeText.textContent = `${pageLabel}。像 chrome://、edge://、扩展页这类浏览器内部页面，即使授权所有网站也不能读取。请在普通 http/https 页面使用。`;
      break;
    case "clipboard-failed":
      noticeTitle.textContent = "扩展没能写入剪贴板";
      noticeText.textContent = `${pageLabel}。这次不是站点没授权，而是扩展自身写剪贴板失败。通常重载扩展后可恢复；如果还不行，再把浏览器控制台里的最新报错贴出来。`;
      break;
    default:
      noticeBanner.hidden = true;
  }
}

function truncate(value: string, maxLength: number): string {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, maxLength - 1)}…`;
}
