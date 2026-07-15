import { defineConfig } from "wxt";

export default defineConfig({
  manifest: ({ browser }) => ({
    name: "MdMonitor Quick Capture",
    short_name: "MdMonitor",
    description: "Copy the current page as a Markdown link for MdMonitor.",
    permissions: [
      "activeTab",
      "scripting",
      "storage",
      "clipboardWrite",
      ...(browser === "chrome" || browser === "edge" ? ["offscreen"] : [])
    ],
    optional_host_permissions: ["<all_urls>"],
    action: {
      default_title: "Copy page as Markdown link"
    },
    icons: {
      "16": "icons/icon-16.png",
      "32": "icons/icon-32.png",
      "48": "icons/icon-48.png",
      "96": "icons/icon-96.png",
      "128": "icons/icon-128.png"
    },
    browser_specific_settings: {
      gecko: {
        id: "mdmonitor-quick-capture@etng.github.com"
      }
    }
  })
});
