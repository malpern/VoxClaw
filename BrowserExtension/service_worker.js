const POLL_INTERVAL_MS = 1000;
const STATUS_URL = "http://localhost:4140/status";

// Spotify ducking: lower playing tabs to this volume while speaking, with
// short fades so it reads as ducking rather than a glitch. Restore is held
// briefly because /status flips to not-reading during the queue's 1s
// inter-item gap — without the hold, volume yo-yos between queued utterances.
const DUCK_VOLUME = 0.2;
const FADE_DOWN_MS = 300;
const FADE_UP_MS = 500;
const RESTORE_HOLD_MS = 1500;

let wasReading = false;
let pausedTabs = [];
let duckedTabs = [];
let restoreTimer = null;
let pollTimer = null;

function log(...args) {
  console.log("[VoxClaw]", ...args);
}

async function pollStatus() {
  try {
    const response = await fetch(STATUS_URL, { signal: AbortSignal.timeout(2000) });
    const data = await response.json();
    const isReading = data.reading === true;

    chrome.action.setIcon({
      path: isReading
        ? { "16": "icons/icon16.png", "32": "icons/icon32.png" }
        : { "16": "icons/icon16.png", "32": "icons/icon32.png" }
    });
    chrome.action.setTitle({
      title: isReading ? "VoxClaw is speaking" : "VoxClaw"
    });

    if (isReading && !wasReading) {
      pausedTabs = await pauseYouTube();
      log(`Speaking started, paused ${pausedTabs.length} tab(s)`);
      if (restoreTimer) {
        // Speech resumed within the hold window — stay ducked.
        clearTimeout(restoreTimer);
        restoreTimer = null;
      } else if (duckedTabs.length === 0) {
        duckedTabs = await duckSpotify();
        log(`Ducked ${duckedTabs.length} Spotify tab(s)`);
      }
    } else if (!isReading && wasReading) {
      if (pausedTabs.length > 0) {
        await resumeYouTube(pausedTabs);
        log(`Speaking finished, resumed ${pausedTabs.length} tab(s)`);
        pausedTabs = [];
      }
      scheduleSpotifyRestore();
    }

    wasReading = isReading;
  } catch {
    // This chrome.* call is load-bearing beyond the title it sets: extension API
    // activity is what resets the service worker's idle timer. The success path
    // above calls chrome.action every second, but without a call here the worker
    // goes idle while VoxClaw is unreachable and is torn down — taking the poll
    // interval with it, so ducking never resumes once VoxClaw comes back.
    chrome.action.setTitle({ title: "VoxClaw (not running)" });

    if (wasReading) {
      wasReading = false;
      if (pausedTabs.length > 0) {
        await resumeYouTube(pausedTabs);
        pausedTabs = [];
      }
    }
    // Listener gone — restore immediately rather than waiting out the hold.
    if (restoreTimer) {
      clearTimeout(restoreTimer);
      restoreTimer = null;
    }
    if (duckedTabs.length > 0) {
      const tabs = duckedTabs;
      duckedTabs = [];
      await restoreSpotify(tabs);
    }
  }
}

function scheduleSpotifyRestore() {
  if (restoreTimer || duckedTabs.length === 0) return;
  restoreTimer = setTimeout(async () => {
    restoreTimer = null;
    const tabs = duckedTabs;
    duckedTabs = [];
    await restoreSpotify(tabs);
    log(`Restored volume on ${tabs.length} Spotify tab(s)`);
  }, RESTORE_HOLD_MS);
}

async function duckSpotify() {
  const tabs = await chrome.tabs.query({ url: ["https://open.spotify.com/*"] });

  const ducked = [];
  for (const tab of tabs) {
    if (!tab.id) continue;
    try {
      const [{ result } = {}] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: (duckVolume, fadeMs) => {
          const media = [...document.querySelectorAll("video, audio")].find(
            el => !el.paused && !el.ended && el.readyState >= 2 && el.volume > duckVolume
          );
          if (!media) return null;
          const from = media.volume;
          const start = performance.now();
          const step = now => {
            const t = Math.min((now - start) / fadeMs, 1);
            media.volume = from + (duckVolume - from) * t;
            if (t < 1) requestAnimationFrame(step);
          };
          requestAnimationFrame(step);
          return from;
        },
        args: [DUCK_VOLUME, FADE_DOWN_MS]
      });
      if (result !== null && result !== undefined) {
        ducked.push({ tabId: tab.id, volume: result });
      }
    } catch {}
  }
  return ducked;
}

async function restoreSpotify(tabs) {
  for (const { tabId, volume } of tabs) {
    try {
      const tab = await chrome.tabs.get(tabId);
      if (!tab?.url?.startsWith("https://open.spotify.com/")) continue;
      await chrome.scripting.executeScript({
        target: { tabId },
        func: (targetVolume, fadeMs) => {
          // Restore even if playback was paused mid-speech, so the next
          // play resumes at the original volume.
          const media = document.querySelector("video, audio");
          if (!media || media.volume >= targetVolume) return;
          const from = media.volume;
          const start = performance.now();
          const step = now => {
            const t = Math.min((now - start) / fadeMs, 1);
            media.volume = from + (targetVolume - from) * t;
            if (t < 1) requestAnimationFrame(step);
          };
          requestAnimationFrame(step);
        },
        args: [volume, FADE_UP_MS]
      });
    } catch {}
  }
}

async function pauseYouTube() {
  const tabs = await chrome.tabs.query({
    url: [
      "https://*.youtube.com/*",
      "https://youtube.com/*",
      "https://youtu.be/*",
      "https://*.youtube-nocookie.com/*"
    ]
  });

  const paused = [];
  for (const tab of tabs) {
    if (!tab.id || !tab.url) continue;
    try {
      const [{ result } = {}] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: () => {
          const video = document.querySelector("video");
          if (!video || video.paused || video.ended || video.readyState < 2) {
            return false;
          }
          video.pause();
          return true;
        }
      });
      if (result) {
        paused.push({ tabId: tab.id, url: tab.url });
      }
    } catch {}
  }
  return paused;
}

async function resumeYouTube(tabs) {
  for (const { tabId, url } of tabs) {
    try {
      const tab = await chrome.tabs.get(tabId);
      if (!tab?.url || tab.url !== url) continue;
      await chrome.scripting.executeScript({
        target: { tabId },
        func: () => {
          const video = document.querySelector("video");
          if (video?.paused && !video.ended) {
            void video.play();
          }
        }
      });
    } catch {}
  }
}

function startPolling() {
  if (pollTimer) return;
  pollTimer = setInterval(pollStatus, POLL_INTERVAL_MS);
  pollStatus();
  log("Polling started");
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
  if (restoreTimer) {
    clearTimeout(restoreTimer);
    restoreTimer = null;
  }
  if (duckedTabs.length > 0) {
    const tabs = duckedTabs;
    duckedTabs = [];
    void restoreSpotify(tabs);
  }
  log("Polling stopped");
}

// A service worker is torn down after ~30s without extension API activity.
// While VoxClaw is unreachable pollStatus takes its catch path, which makes no
// chrome.* calls, so the worker dies — and setInterval dies with it. Nothing
// would restart it, because startPolling only runs on install/startup, so a
// single VoxClaw restart used to disable the extension until the browser was
// restarted. This alarm wakes the worker back up and restarts the loop.
const WATCHDOG_ALARM = "voxclaw-poll-watchdog";
// 30s is the shortest period Chrome honors for alarms.
chrome.alarms.create(WATCHDOG_ALARM, { periodInMinutes: 0.5 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name !== WATCHDOG_ALARM) return;
  chrome.storage.local.get("enabled", ({ enabled }) => {
    if (enabled !== false) startPolling();
  });
});

chrome.storage.local.get("enabled", ({ enabled }) => {
  if (enabled !== false) startPolling();
});

chrome.storage.onChanged.addListener((changes) => {
  if (changes.enabled) {
    if (changes.enabled.newValue === false) {
      stopPolling();
    } else {
      startPolling();
    }
  }
});

chrome.runtime.onStartup.addListener(() => {
  chrome.storage.local.get("enabled", ({ enabled }) => {
    if (enabled !== false) startPolling();
  });
});

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.get("enabled", ({ enabled }) => {
    if (enabled !== false) startPolling();
  });
});
