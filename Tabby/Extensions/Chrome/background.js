// background.js — Tabby Chrome Extension
//
// This service worker:
// 1. Connects to the Tabby macOS app via Native Messaging
// 2. Enumerates all open tabs and sends updates
// 3. Subscribes to tab events (created, updated, removed, activated)
// 4. Receives "activateTab" commands from the macOS app
//
// Native Messaging host name must match the manifest installed by the macOS app.

const NATIVE_HOST_NAME = "com.tabby.native_host";
const BROWSER_NAME = "chrome";

// ============================================================
// Native Messaging Connection
// ============================================================

let port = null;
let reconnectTimer = null;

/**
 * Connect to the native messaging host.
 * The host binary is launched by Chrome and communicates via stdin/stdout.
 */
function connectToHost() {
  try {
    port = chrome.runtime.connectNative(NATIVE_HOST_NAME);
    console.log("[Tabby] Connected to native host");

    // Listen for messages from the macOS app
    port.onMessage.addListener(handleNativeMessage);

    // Handle disconnection
    port.onDisconnect.addListener(() => {
      const error = chrome.runtime.lastError;
      console.log("[Tabby] Disconnected from native host:", error?.message || "unknown reason");
      port = null;

      // Attempt reconnection after a delay
      scheduleReconnect();
    });

    // Send initial tab enumeration
    sendTabUpdate();

  } catch (error) {
    console.error("[Tabby] Failed to connect to native host:", error);
    scheduleReconnect();
  }
}

/**
 * Schedule a reconnection attempt.
 */
function scheduleReconnect() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
  }
  reconnectTimer = setTimeout(() => {
    console.log("[Tabby] Attempting reconnection...");
    connectToHost();
  }, 5000); // Retry every 5 seconds
}

/**
 * Send a message to the native host.
 * Native Messaging handles the length-prefixed framing automatically.
 */
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

/**
 * Convert a Blob to a base64 data URI string.
 * Uses arrayBuffer() instead of FileReader for reliable service worker support.
 * Returns a string like "data:image/png;base64,iVBORw0KGgo..."
 */
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

/**
 * Enumerate all open tabs and send the data to the macOS app.
 */
async function sendTabUpdate() {
  try {
    const tabs = await chrome.tabs.query({});

    // Build the tab data array with favicons converted to base64 data URIs
    const tabData = await Promise.all(tabs.map(async (tab) => {
      let favicon = null;

      // Try Chrome's _favicon API first (local, no CORS issues).
      // Falls back to sending the raw favIconUrl for the macOS app to fetch.
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

      // If base64 conversion failed, send the raw favicon URL as fallback
      // so the macOS app can fetch it directly
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

/**
 * Handle messages received from the macOS app via Native Messaging.
 */
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

/**
 * Close a specific tab by its ID.
 */
async function closeTab(tabId) {
  try {
    await chrome.tabs.remove(tabId);
    console.log(`[Tabby] Closed tab ${tabId}`);
    sendTabUpdate();
  } catch (error) {
    console.error(`[Tabby] Failed to close tab ${tabId}:`, error);
  }
}

/**
 * Close all tabs in the browser.
 */
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

/**
 * Activate (switch to) a specific tab in a specific window.
 */
async function activateTab(tabId, windowId) {
  try {
    // First, focus the window
    await chrome.windows.update(windowId, { focused: true });

    // Then, activate the tab
    await chrome.tabs.update(tabId, { active: true });

    console.log(`[Tabby] Activated tab ${tabId} in window ${windowId}`);
  } catch (error) {
    console.error(`[Tabby] Failed to activate tab ${tabId}:`, error);
  }
}

// ============================================================
// Tab Event Listeners
// ============================================================

// Send updates when tabs are created
chrome.tabs.onCreated.addListener(() => {
  sendTabUpdate();
});

// Send updates when tabs are updated (URL change, title change, etc.)
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  // Only send update when relevant properties change
  if (changeInfo.title !== undefined ||
      changeInfo.url !== undefined ||
      changeInfo.status === "complete" ||
      changeInfo.favIconUrl !== undefined) {
    sendTabUpdate();
  }
});

// Send updates when tabs are removed
chrome.tabs.onRemoved.addListener(() => {
  sendTabUpdate();
});

// Send updates when the active tab changes
chrome.tabs.onActivated.addListener(() => {
  sendTabUpdate();
});

// Send updates when a tab is moved
chrome.tabs.onMoved.addListener(() => {
  sendTabUpdate();
});

// Send updates when a tab is attached to a window
chrome.tabs.onAttached.addListener(() => {
  sendTabUpdate();
});

// Send updates when a tab is detached from a window
chrome.tabs.onDetached.addListener(() => {
  sendTabUpdate();
});

// Send updates when a window is created or removed
chrome.windows.onCreated.addListener(() => {
  sendTabUpdate();
});

chrome.windows.onRemoved.addListener(() => {
  sendTabUpdate();
});

// ============================================================
// Initialization
// ============================================================

// Connect to the native host when the service worker starts
connectToHost();

console.log("[Tabby] Chrome extension background script loaded");
