// background.js — Tabby Edge Extension
//
// This service worker is nearly identical to the Chrome version since Edge
// is Chromium-based and supports the same APIs. The only difference is the
// BROWSER_NAME constant used to identify tabs as coming from Edge.
//
// See Chrome/background.js for detailed comments.

const NATIVE_HOST_NAME = "com.tabby.native_host";
const BROWSER_NAME = "edge";

// ============================================================
// Native Messaging Connection
// ============================================================

let port = null;
let reconnectTimer = null;

function connectToHost() {
  try {
    port = chrome.runtime.connectNative(NATIVE_HOST_NAME);
    console.log("[Tabby] Connected to native host");

    port.onMessage.addListener(handleNativeMessage);

    port.onDisconnect.addListener(() => {
      const error = chrome.runtime.lastError;
      console.log("[Tabby] Disconnected from native host:", error?.message || "unknown reason");
      port = null;
      scheduleReconnect();
    });

    sendTabUpdate();

  } catch (error) {
    console.error("[Tabby] Failed to connect to native host:", error);
    scheduleReconnect();
  }
}

function scheduleReconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }
  reconnectTimer = setTimeout(() => {
    console.log("[Tabby] Attempting reconnection...");
    connectToHost();
  }, 5000);
}

function sendToHost(message) {
  if (port) {
    try {
      port.postMessage(message);
    } catch (error) {
      console.error("[Tabby] Failed to send message:", error);
    }
  } else {
    console.warn("[Tabby] Not connected to native host, message dropped");
  }
}

// ============================================================
// Utilities
// ============================================================

async function blobToDataURI(blob) {
  const buffer = await blob.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  const base64 = btoa(binary);
  return `data:${blob.type || 'image/png'};base64,${base64}`;
}

// ============================================================
// Tab Enumeration
// ============================================================

async function sendTabUpdate() {
  try {
    const tabs = await chrome.tabs.query({});

    const tabData = await Promise.all(tabs.map(async (tab) => {
      let favicon = null;

      if (tab.url) {
        try {
          const faviconApiUrl = `chrome-extension://${chrome.runtime.id}/_favicon/?pageUrl=${encodeURIComponent(tab.url)}&size=32`;
          const response = await fetch(faviconApiUrl);
          if (response.ok) {
            const blob = await response.blob();
            if (blob.size > 0) {
              favicon = await blobToDataURI(blob);
              console.log(`[Tabby] Favicon OK for "${tab.title?.substring(0, 30)}": ${favicon.substring(0, 60)}... (${favicon.length} chars)`);
            } else {
              console.log(`[Tabby] Empty blob for "${tab.title?.substring(0, 30)}"`);
            }
          } else {
            console.log(`[Tabby] _favicon fetch failed for "${tab.title?.substring(0, 30)}": status ${response.status}`);
          }
        } catch (e) {
          console.log(`[Tabby] _favicon error for "${tab.title?.substring(0, 30)}":`, e.message);
        }
      }

      if (!favicon && tab.favIconUrl) {
        favicon = tab.favIconUrl;
        console.log(`[Tabby] Using favIconUrl fallback for "${tab.title?.substring(0, 30)}": ${favicon.substring(0, 80)}`);
      }

      return {
        tabId: tab.id,
        windowId: tab.windowId,
        title: tab.title || "",
        url: tab.url || "",
        favicon: favicon
      };
    }));

    const message = {
      type: "tabUpdate",
      browser: BROWSER_NAME,
      tabs: tabData
    };

    sendToHost(message);
    console.log(`[Tabby] Sent tab update: ${tabData.length} tabs`);

  } catch (error) {
    console.error("[Tabby] Failed to enumerate tabs:", error);
  }
}

// ============================================================
// Inbound Message Handling
// ============================================================

function handleNativeMessage(message) {
  console.log("[Tabby] Received native message:", message);

  switch (message.type) {
    case "activateTab":
      activateTab(message.tabId, message.windowId);
      break;
    case "requestTabs":
      sendTabUpdate();
      break;
    case "closeTab":
      closeTab(message.tabId);
      break;
    case "closeAllTabs":
      closeAllTabs();
      break;
    default:
      console.warn("[Tabby] Unknown message type:", message.type);
  }
}

async function closeTab(tabId) {
  try {
    await chrome.tabs.remove(tabId);
    console.log(`[Tabby] Closed tab ${tabId}`);
    sendTabUpdate();
  } catch (error) {
    console.error(`[Tabby] Failed to close tab ${tabId}:`, error);
  }
}

async function closeAllTabs() {
  try {
    const tabs = await chrome.tabs.query({});
    const tabIds = tabs.map(t => t.id);
    await chrome.tabs.remove(tabIds);
    console.log(`[Tabby] Closed all ${tabIds.length} tabs`);
    sendTabUpdate();
  } catch (error) {
    console.error("[Tabby] Failed to close all tabs:", error);
  }
}

async function activateTab(tabId, windowId) {
  try {
    await chrome.windows.update(windowId, { focused: true });
    await chrome.tabs.update(tabId, { active: true });
    console.log(`[Tabby] Activated tab ${tabId} in window ${windowId}`);
  } catch (error) {
    console.error(`[Tabby] Failed to activate tab ${tabId}:`, error);
  }
}

// ============================================================
// Tab Event Listeners
// ============================================================

chrome.tabs.onCreated.addListener(() => sendTabUpdate());
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.title !== undefined ||
      changeInfo.url !== undefined ||
      changeInfo.status === "complete" ||
      changeInfo.favIconUrl !== undefined) {
    sendTabUpdate();
  }
});
chrome.tabs.onRemoved.addListener(() => sendTabUpdate());
chrome.tabs.onActivated.addListener(() => sendTabUpdate());
chrome.tabs.onMoved.addListener(() => sendTabUpdate());
chrome.tabs.onAttached.addListener(() => sendTabUpdate());
chrome.tabs.onDetached.addListener(() => sendTabUpdate());
chrome.windows.onCreated.addListener(() => sendTabUpdate());
chrome.windows.onRemoved.addListener(() => sendTabUpdate());

// ============================================================
// Initialization
// ============================================================

connectToHost();
console.log("[Tabby] Edge extension background script loaded");
