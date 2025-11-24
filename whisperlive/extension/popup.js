let recording = false;
let ws = null;
let stream = null;
let audioCtx = null;
let processor = null;

const micBtn = document.getElementById("micBtn");
const micLabel = document.getElementById("micLabel");
const micIcon = document.getElementById("micIcon");
const copyBtn = document.getElementById("copyBtn");
const transcriptEl = document.getElementById("transcript");
const statusEl = document.getElementById("status");

let appended = [];

function setStatus(text) {
  statusEl.textContent = text;
}

async function loadConfig() {
  const { endpoint, model } = await chrome.storage.sync.get({
    endpoint: "",
    model: "small"
  });
  return { endpoint, model };
}

async function startRecording() {
  const { endpoint, model } = await loadConfig();
  if (!endpoint) {
    setStatus("Please configure the WebSocket endpoint in Settings.");
    return;
  }

  try {
    setStatus("Requesting microphone…");
    stream = await navigator.mediaDevices.getUserMedia({ audio: true });

    audioCtx = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: 16000
    });

    const src = audioCtx.createMediaStreamSource(stream);
    processor = audioCtx.createScriptProcessor(4096, 1, 1);

    ws = new WebSocket(endpoint);

    ws.onopen = () => {
      ws.send(JSON.stringify({
        uid: Math.random().toString(36).slice(2),
        language: null,
        task: "transcribe",
        model,
        use_vad: true,
        send_last_n_segments: 10
      }));
      setStatus("Connected. Speak!");
      recording = true;
      micBtn.dataset.state = "recording";
      micIcon.dataset.state = "recording";
      micLabel.textContent = "Stop";
    };

    ws.onerror = (e) => {
      console.error("WebSocket error", e);
      setStatus("WebSocket error. Check endpoint.");
      stopRecording();
    };

    ws.onclose = () => {
      if (recording) {
        setStatus("Connection closed.");
        stopRecording();
      }
    };

    ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.segments && msg.segments.length) {
          const text = msg.segments.map(s => s.text).join(" ");
          transcriptEl.textContent = text;
        }
      } catch (err) {
        console.error("Bad message", err);
      }
    };

    processor.onaudioprocess = (ev) => {
      if (!recording || !ws || ws.readyState !== 1) return;
      const input = ev.inputBuffer.getChannelData(0);
      // Send raw Float32 PCM
      ws.send(input.buffer);
    };

    src.connect(processor);
    processor.connect(audioCtx.destination);
  } catch (err) {
    console.error(err);
    setStatus("Failed to access microphone.");
    cleanup();
  }
}

function cleanup() {
  try { processor && processor.disconnect(); } catch {}
  try { audioCtx && audioCtx.close(); } catch {}
  try { stream && stream.getTracks().forEach(t => t.stop()); } catch {}
  try { ws && ws.close(); } catch {}
  ws = null;
  processor = null;
  audioCtx = null;
  stream = null;
}

function stopRecording() {
  if (!recording) return;
  recording = false;
  setStatus("Stopped.");
  micBtn.dataset.state = "idle";
  micIcon.dataset.state = "idle";
  micLabel.textContent = "Start";
  try {
    ws && ws.readyState === 1 && ws.send("END_OF_AUDIO");
  } catch {}
  cleanup();
}

micBtn.addEventListener("click", () => {
  if (recording) {
    stopRecording();
  } else {
    startRecording();
  }
});

copyBtn.addEventListener("click", () => {
  const text = transcriptEl.textContent || "";
  if (!text.trim()) {
    setStatus("Nothing to copy yet.");
    return;
  }
  navigator.clipboard.writeText(text);
  setStatus("Copied to clipboard.");
});

document.getElementById("settingsBtn").addEventListener("click", () => {
  chrome.runtime.openOptionsPage();
});