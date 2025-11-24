import asyncio
import json
import websockets
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
import io, os, zipfile
from fastapi import HTTPException
from fastapi.responses import StreamingResponse

app = FastAPI()

WHISPER_HOST = "192.168.27.13"
WHISPER_PORT = 9090
WHISPER_WS_URL = f"ws://{WHISPER_HOST}:{WHISPER_PORT}/ws"

HTML_PAGE = r"""
<!DOCTYPE html>
<html data-theme="auto">
<head>
<meta charset="utf-8"/>
<title>WhisperLive Web Client</title>

<style>
/* ============================================
  Modern Typography + Theme + UI Polish
  ============================================ */

:root {
  --bg-dark:#0b1020;
  --fg-dark:#e8e8ee;

  --bg-light:#fafbfc;
  --fg-light:#111;

  --accent:#e91e63;
  --accent-glow:rgba(233,30,99,0.65);

  --font-main:"Inter", -apple-system, BlinkMacSystemFont, "Segoe UI",
          Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;

  --radius:14px;
}

@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

html, body, #app, #transcript {
  font-family:var(--font-main);
  transition: background 0.35s ease, color 0.35s ease;
}

html[data-theme="dark"] body { background:var(--bg-dark); color:var(--fg-dark); }
html[data-theme="light"] body { background:var(--bg-light); color:var(--fg-light); }
html[data-theme="auto"] { color-scheme: light dark; }

#app { width:100%; max-width:1200px; padding-bottom:20px; position:relative; }

/* ===== Theme Toggle (top-right) ===== */
#themeToggle {
  position:absolute;
  top:18px;
  right:18px;
  background:none;
  border:none;
  cursor:pointer;
  padding:6px;
  border-radius:50%;
  width:42px; height:42px;
  display:flex;
  justify-content:center;
  align-items:center;
  transition:background .2s, transform .2s;
}
#themeToggle:hover { background:rgba(255,255,255,0.08); transform:scale(1.08); }

/* ===== Title ===== */
h1 {
  text-align:center;
  margin-top:48px;
  margin-bottom:4px;
  font-weight:700;
  font-size:2rem;
  letter-spacing:-0.015em;
}

/* ===== Centered Status ===== */
#status {
  margin-top:10px;
  text-align:center;
  font-size:17px;
  font-weight:500;
  opacity:0.9;
}

/* ===== Microphone ===== */
#mic {
  width:150px;
  height:150px;
  border-radius:50%;
  background:var(--accent);
  display:flex;
  justify-content:center;
  align-items:center;
  cursor:pointer;
  margin:20px auto;
  box-shadow:0 0 40px var(--accent-glow);
  transition:transform .15s, box-shadow .15s;
}
#mic:hover { transform:scale(1.06); box-shadow:0 0 55px var(--accent-glow); }
#mic.active { animation:pulse 1.25s infinite; }

@keyframes pulse {
  0% { transform:scale(1); }
  50% { transform:scale(1.14); }
  100% { transform:scale(1); }
}

/* ===== Transcript Area ===== */
#transcript {
  background:rgba(255,255,255,0.06);
  padding:26px;
  border-radius:var(--radius);
  min-height:250px;
  font-size:20px;
  line-height:1.55;
  overflow-y:auto;
  font-weight:400;
  box-shadow:0 12px 40px rgba(0,0,0,0.33);
  margin-top:10px;
}

/* Language section headers */
.lang-block {
  margin-bottom:20px;
  padding-bottom:6px;
  border-bottom:1px solid rgba(255,255,255,0.1);
}
.lang-label {
  font-weight:700;
  opacity:0.85;
  margin-bottom:8px;
}

/* Final lines */
.hist-line {
  opacity:0.58;
  margin-bottom:10px;
  font-weight:300;
  font-style: italic;
  animation:fadein .28s ease;
}

/* Live line */
.live-line {
  margin-top:8px;
  font-size:1.75em;
  font-weight:750;
}

/* Karaoke styling */
.kword { position:relative; padding-right:4px; }
.kword.active::after {
  content:"";
  position:absolute;
  left:0; bottom:-4px;
  width:100%; height:3px;
  background:var(--accent);
  border-radius:2px;
  animation:underline .25s ease;
}
@keyframes underline {
  from { transform:scaleX(0); }
  to   { transform:scaleX(1); }
}

/* caret */
.caret {
  display:inline-block;
  width:10px;
  height:1.35em;
  background:var(--accent);
  margin-left:6px;
  animation:blink .9s infinite;
  border-radius:2px;
}
@keyframes blink { 0%,49% {opacity:1;} 50%,100% {opacity:0;} }

@keyframes fadein {
  from {opacity:0; transform:translateY(10px);}
  to   {opacity:1; transform:translateY(0);}
}

/* ===== Help panel (floating) ===== */
#helpButton{
  position:fixed; right:18px; bottom:18px; z-index:1200;
  width:54px; height:54px; border-radius:50%; background:var(--accent);
  color:white; display:flex; align-items:center; justify-content:center;
  box-shadow:0 10px 30px rgba(0,0,0,0.35); border:none; cursor:pointer;
}
#helpButton:hover{ transform:scale(1.06); }

#helpPanel{
  position:fixed; right:18px; bottom:86px; z-index:1200;
  width:360px; max-width:calc(100% - 48px); background:var(--bg-dark);
  color:var(--fg-dark); border-radius:12px; padding:16px; box-shadow:0 20px 60px rgba(0,0,0,0.45);
  transform:translateY(12px); opacity:0; pointer-events:none; transition:all .22s ease;
}
#helpPanel.open{ transform:translateY(0); opacity:1; pointer-events:auto; }
#helpPanel h3{ margin-top:0; margin-bottom:8px; }
#helpPanel p{ margin:6px 0; font-size:14px; opacity:0.95 }
#helpPanel li{ margin:6px 0; font-size:14px; opacity:0.95 }
#helpPanel .download{ display:inline-block; margin-top:8px; padding:8px 12px; background:var(--accent); color:#fff; border-radius:8px; text-decoration:none; }
#helpPanel .closeX{ position:absolute; right:8px; top:8px; background:none; border:none; color:inherit; font-weight:700; cursor:pointer; }
</style>
</head>

<body>
<div id="app">

<h1>Whisper Live Transcription</h1>

<button id="themeToggle" title="Toggle Theme">
  <svg width="26" height="26" viewBox="0 0 24 24" fill="none"
   stroke="currentColor" stroke-width="2" stroke-linecap="round"
   stroke-linejoin="round">
  <path d="M12 3a9 9 0 0 0 9 9 9 9 0 1 1-9-9z"/>
  </svg>
</button>

<!-- Language selector (override) -->
<div id="langControl" title="Language override">
  <select id="langSelect" onchange="onLangChange()">
  <option value="">Auto detect</option>
  <option value="en">English</option>
  <option value="es">Spanish</option>
  <option value="fr">French</option>
  <option value="de">German</option>
  <option value="zh">Chinese (zh)</option>
  <option value="ja">Japanese</option>
  <option value="hi">Hindi</option>
  <option value="te">Telugu</option>
  <option value="ta">Tamil</option>
  </select>
</div>

<div id="status">Idle</div>

<!-- Mic Button -->
<div id="mic" onclick="toggleRecord()">
  <svg width="70" height="70" viewBox="0 0 24 24" fill="white">
  <path d="M12 14a3 3 0 0 0 3-3V5a3 3 0 1 0-6 0v6a3 3 3 0 0 0 3 3z"/>
  <path d="M19 11a1 1 0 0 0-2 0 5 5 0 0 1-10 0 1 1 0 0 0-2 0 7 7 0 0 0 6 6.92V21H9a1 1 0 0 0 0 2h6a1 1 0 0 0 0-2h-2v-3.08A7 7 0 0 0 19 11z"/>
  </svg>
</div>

<!-- Transcript Container -->
<div id="transcript"></div>

</div><!-- app -->

<!-- Floating Help Button & Panel -->
<button id="helpButton" title="Help" onclick="toggleHelp()">?
</button>

<div id="helpPanel" aria-hidden="true">
  <button class="closeX" onclick="closeHelp()">✕</button>
  <h3>Chrome / Edge WhisperLive Extension</h3>
  <p>Install the browser extension to enable sending audio directly from the page, improved tab capture, or to load local files into WhisperLive.</p>
  <!-- Open the download in a new tab/window for users -->
  <a id="extDownload" class="download" href="/extension.zip" target="_blank" rel="noopener noreferrer" onclick="window.open('/extension.zip','_blank'); return false;">Download extension</a>.
  <p></p>

  <hr/>
  <h4>Extension Installation (Load Unpacked)</h4>
  <ol>
  <li>Unzip the downloaded <code>extension.zip</code>.</li>
  <li>Open <a href="chrome://extensions" target="_chromeext"><code>chrome://extensions</code></a>, enable "Developer mode", click "Load unpacked" and select the unzipped extension folder.</li>
  <li>Open the extension's <code>Options</code> and set the endpoint to <code>ws://hostname:port/ws</code> (replace <code>hostname</code> and <code>port</code> with your server address and port).</li>
  <li>Finally, open the extension popup to grant microphone permission: navigate to <code>chrome-extension://&lt;extensionid&gt;/popup.html</code> (replace <code>&lt;extensionid&gt;</code> with the installed extension's id) and click "Allow" when prompted for Microphone access.</li>
  </ol>

  <hr/>
  <h4>About this HTML Live Transcript Page</h4>
  <p>This page streams microphone audio to a WhisperLive backend and shows live partials (karaoke-style) and finalized transcript lines. Use the language dropdown to override automatic language detection. Click the mic to start/stop.</p>
</div>

<script>
let ws=null, audioCtx=null, processor=null, stream=null;

let recording=false, serverReady=false;
let appended = new Set();
let silenceTimer=null;
let languageOverride = null; // null => auto-detect, otherwise language code like 'en'

let currentLang = null;       // e.g. "en"
let currentLangBlock = null;  // DOM element for that section

const transcriptEl = document.getElementById("transcript");
const STATUS = txt => document.getElementById("status").innerText = txt;

/* ================================
  Utility: map language → flag
================================== */
function langFlag(code) {
  const map = {
  en:"🇺🇸", fr:"🇫🇷", es:"🇪🇸", de:"🇩🇪",
  it:"🇮🇹", pt:"🇵🇹", ru:"🇷🇺", zh:"🇨🇳",
  ja:"🇯🇵", ko:"🇰🇷",
  hi:"🇮🇳", ta:"🇮🇳", te:"🇮🇳"
  };
  return map[code] || "🌐";
}

/* ================================
  Create a new language section
================================== */
function createLangBlock(langCode, displayName) {
  const block = document.createElement("div");
  block.className = "lang-block";

  const header = document.createElement("div");
  header.className = "lang-label";
  header.innerText = `${langFlag(langCode)}  ${displayName}`;

  const history = document.createElement("div");
  history.className = "lang-history";

  const live = document.createElement("div");
  live.className = "live-line";

  block.appendChild(header);
  block.appendChild(history);
  block.appendChild(live);

  transcriptEl.appendChild(block);
  transcriptEl.scrollTop = transcriptEl.scrollHeight;

  return { block, history, live };
}

/* ================================
  Theme toggle
================================== */
function toggleTheme(){
  const html=document.documentElement;
  const cur=html.getAttribute("data-theme");
  const next = cur==="dark" ? "light" :
       cur==="light"? "auto" : "dark";
  html.setAttribute("data-theme",next);
}
document.getElementById("themeToggle").onclick=toggleTheme;

function onLangChange(){
  const v = document.getElementById('langSelect').value;
  languageOverride = (v === "" ? null : v);
  // show current override in the status line if not recording
  if (!recording){
  STATUS(languageOverride ? `Language override: ${languageOverride}` : 'Language: auto-detect');
  }
}

/* ================================
  Recording toggle
================================== */
function toggleRecord(){
  if (!recording) startRecord();
  else stopRecord();
}

function resetTranscript() {
  transcriptEl.innerHTML = "";
  appended.clear();
  currentLang = null;
  currentLangBlock = null;
}

/* ================================
  Start recording
================================== */
async function startRecord(){
  recording=true;
  serverReady=false;
  resetTranscript();
  document.getElementById("mic").classList.add("active");

  STATUS("Requesting mic…");

  stream = await navigator.mediaDevices.getUserMedia({audio:true});
  audioCtx = new AudioContext({sampleRate:16000});
  if (audioCtx.state==="suspended") await audioCtx.resume();

  const src = audioCtx.createMediaStreamSource(stream);
  processor = audioCtx.createScriptProcessor(4096,1,1);

  processor.onaudioprocess = e=>{
   if (!serverReady || ws?.readyState!==1) return;
   ws.send(e.inputBuffer.getChannelData(0).buffer);
  };

  src.connect(processor);
  processor.connect(audioCtx.destination);

  ws = new WebSocket("ws://"+window.location.host+"/ws");

  ws.onopen = ()=>{
   STATUS("Sending config…");
   ws.send(JSON.stringify({
    uid:Math.random().toString(36).slice(2),
    language: languageOverride,    // null => auto detect
    task:"transcribe",
    model:"turbo",
    use_vad:true,
    send_last_n_segments:10,
    no_speech_thresh:0.45,
    clip_audio:false,
    same_output_threshold:10,
    enable_translation:false,
    target_language:"en"
   }));
  };

  ws.onmessage = ev=>{
   let msg; try{ msg=JSON.parse(ev.data);}catch{return;}

   if (msg.message==="SERVER_READY"){
    serverReady=true;
    STATUS("Speak now!");
    return;
   }

   if (msg.language){
    const code = msg.language;
    const name = (new Intl.DisplayNames([code], {type:"language"})).of(code) || code;

    if (languageOverride){
      // Show detection but respect user's override; ensure the UI section
      // corresponds to the override language so incoming segments display
      // in the expected block.
      STATUS(`Detected: ${name} (override: ${languageOverride})`);
      if (currentLang !== languageOverride){
       const disp = (new Intl.DisplayNames([languageOverride], {type:'language'})).of(languageOverride) || languageOverride;
       currentLang = languageOverride;
       currentLangBlock = createLangBlock(languageOverride, disp);
      }
    } else {
      STATUS(`Detected: ${name}`);
      if (code !== currentLang) {
       currentLang = code;
       currentLangBlock = createLangBlock(code, name);
      }
    }
    return;
   }

   if (!msg.segments || !currentLangBlock) return;

   const finals = msg.segments.filter(s=>s.completed);
   const partials = msg.segments.filter(s=>!s.completed);

   // Append finals
   for (let seg of finals){
    const key = seg.id ?? `${seg.start}-${seg.end}-${seg.text}`;
    if (!appended.has(key)){
      appended.add(key);
      const div=document.createElement("div");
      div.className="hist-line";
      div.innerText=seg.text.trim();
      currentLangBlock.history.appendChild(div);
      transcriptEl.scrollTop = transcriptEl.scrollHeight;
    }
   }

   // Live karaoke
   if (partials.length){
    const text = partials[partials.length-1].text.trim();
    currentLangBlock.live.innerHTML = karaoke(text);
   } else {
    currentLangBlock.live.innerHTML = "";
   }

   resetSilenceDetector(finals.length>0 || partials.length>0);
  };

  ws.onclose = stopRecord;

  STATUS("Mic ready… waiting for SERVER_READY");
}

/* ================================
  Help panel scripting
================================== */
function toggleHelp(){
  const p = document.getElementById('helpPanel');
  if (p.classList.contains('open')) closeHelp();
  else openHelp();
}
function openHelp(){
  const p = document.getElementById('helpPanel');
  p.classList.add('open');
  p.setAttribute('aria-hidden','false');
}
function closeHelp(){
  const p = document.getElementById('helpPanel');
  p.classList.remove('open');
  p.setAttribute('aria-hidden','true');
}

/* ================================
  Karaoke word animator
================================== */
function karaoke(text){
  const words = text.split(/\s+/);
  const idx = words.length - 1;
  return words.map((w,i)=>
   `<span class="kword ${i===idx?'active':''}">${w}</span>`
  ).join(" ") + `<span class="caret"></span>`;
}

/* ================================
  Silence Reset
================================== */
function resetSilenceDetector(hasSpeech){
  clearTimeout(silenceTimer);
  if (hasSpeech){
   silenceTimer = setTimeout(()=>{ 
    if (currentLangBlock) currentLangBlock.live.innerHTML="";
   }, 900);
  }
}

/* ================================
  Stop recording
================================== */
function stopRecord(){
  recording=false;
  document.getElementById("mic").classList.remove("active");

  try{ ws?.send("END_OF_AUDIO"); }catch{}
  try{ ws?.close(); }catch{}

  try{ processor?.disconnect(); }catch{}
  try{ audioCtx?.close(); }catch{}
  try{ stream?.getTracks().forEach(t=>t.stop()); }catch{}

  ws=null; processor=null; audioCtx=null; stream=null;
  STATUS("Stopped");
}
</script>

</body>
</html>

"""

# ======================================================
# FastAPI <-> WhisperLive Relay
# ======================================================

@app.get("/")
async def index():
    return HTMLResponse(HTML_PAGE)

@app.get("/extension.zip")
async def extension():
    root = os.path.join(os.path.dirname(__file__), "extension")
    if not os.path.isdir(root):
      raise HTTPException(status_code=404, detail="extension folder not found")

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zipf:
      for dirpath, dirnames, filenames in os.walk(root):
        for fname in filenames:
          full = os.path.join(dirpath, fname)
          arcname = os.path.join(os.path.basename(root), os.path.relpath(full, root))
          zipf.write(full, arcname)
    buf.seek(0)

    return StreamingResponse(buf, media_type="application/zip",
                 headers={"Content-Disposition": "attachment; filename=extension.zip"})

@app.websocket("/ws")
async def relay(websocket: WebSocket):
    await websocket.accept()
    print(">>> Browser connected")
    print(f">>> Connecting to WhisperLive: {WHISPER_WS_URL}")

    try:
        whisper_ws = await websockets.connect(WHISPER_WS_URL)
        print(">>> Connected to WhisperLive")
    except Exception as e:
        print("!!! WhisperLive connection failed:", e)
        await websocket.close()
        return

    async def browser_to_whisper():
        try:
            while True:
                msg = await websocket.receive()
                if msg["type"] != "websocket.receive":
                    break
                if msg.get("text") is not None:
                    await whisper_ws.send(msg["text"])
                elif msg.get("bytes") is not None:
                    await whisper_ws.send(msg["bytes"])
        except Exception as e:
            print("browser_to_whisper:", e)
        finally:
            try: await whisper_ws.close()
            except: pass

    async def whisper_to_browser():
        try:
            while True:
                data = await whisper_ws.recv()
                if isinstance(data, str):
                    await websocket.send_text(data)
                else:
                    await websocket.send_bytes(data)
        except Exception as e:
            print("whisper_to_browser:", e)
        finally:
            try: await websocket.close()
            except: pass

    await asyncio.gather(browser_to_whisper(), whisper_to_browser())
