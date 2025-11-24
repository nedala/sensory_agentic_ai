# **Meeting AI**

Meeting AI is a privacy-preserving, on-device meeting assistant that processes recorded meetings, performs high-quality speech diarization, generates transcripts, and provides structured meeting summaries using local LLMs via Ollama.

The application runs entirely offline, supports screen-recording input, and produces accurate multi-speaker transcripts and inferred participant identities.

## **Features**

### **1. Record**

* Built-in screen-recording workflow using Streamlit’s screencast tools.
* Optional dummy window mode for privacy-conscious users.
* Audio and screen capture supported.

### **2. Transcribe**

* High-accuracy speech-to-text using Whisper (OpenAI Whisper local model).
* Multi-speaker separation using NVIDIA NeMo Neural Diarizer (TitaNet + MSDD).
* Automatic detection and merging of adjacent speaker segments.
* Produces:

  * Raw transcript JSON
  * Cleaned CSV transcript
  * Temporarily staged audio output

### **3. Summarize**

* Modern summarization pipeline:

  * LlamaIndex for chunking and document structuring
  * LangChain (LCEL) for prompt management
  * Local LLM inference through `ChatOllama`
  * Pydantic structured outputs
* Generates:

  * High-level meeting summary
  * Topic list
  * Action items
  * Decisions
  * Risks
  * Follow-ups
  * Inferred speaker identities (mapping diarized labels → likely real names/roles)

### **4. Local and Private**

* All computation is local: diarization, transcription, and LLM inference.
* No cloud calls or external dependencies.

---

## **Project Structure**

```
app/
│
├── record.py                 # Streamlit UI (3-step workflow with tabs)
├── transcribe_whisper.py     # Whisper + NeMo diarization pipeline
├── summarizer.py             # LlamaIndex + LangChain summarization engine
├── utils.py                  # Audio conversion & file handling utilities
├── static/                   # Sample media and help images
└── config/                   # NeMo diarization configuration (YAML)
```

---

## **Requirements**

Meeting AI depends on several major components:

* **Whisper** (openai-whisper)
* **NVIDIA NeMo** (speaker diarization)
* **LangChain** + **Langchain-Ollama**
* **LlamaIndex**
* **Ollama** with a compatible model (e.g., `neural-chat`)

### **Python Requirements**

A recommended `requirements.txt`:

```
streamlit
streamlit_antd_components
pandas
pydub
openai-whisper
numpy
scipy
huggingface_hub
transformers
langchain
langchain_ollama
langgraph
llama-index
concurrent-log-handler
packaging
setuptools

# NeMo dependencies (requires CUDA)
nemo_toolkit[all]
torch
torchaudio
```

---

## **Installation**

### **1. Install Python environment**

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### **2. Install and start Ollama**

Install from [https://ollama.com/download](https://ollama.com/download)

Then pull the model (or your preferred model):

```bash
ollama pull neural-chat
```

Run it:

```bash
ollama serve
```

### **3. Install NVIDIA CUDA dependencies**

Required for NeMo diarization:

* CUDA Toolkit 11.7+
* cuDNN
* Compatible PyTorch CUDA wheels

(Refer to NVIDIA NeMo installation guides.)

---

## **Running the Application**

From the project root:

```bash
streamlit run app/record.py
```

The UI provides a 3-step workflow:

1. **Record** a meeting
2. **Transcribe** and diarize the audio
3. **Summarize** the meeting content

---

## **Configuration**

### **Disable Folder Watching**

Add to `.streamlit/config.toml`:

```toml
[server]
folderWatchBlacklist = ["./*", "record.py"]
```

### **Model Configuration**

To use a different Ollama model:

```bash
export MODEL_NAME=llama2
export BASE_URL=http://localhost:11434
```
