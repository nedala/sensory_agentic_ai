# Generative AI

Unlock the power of generative AI for everyone—text, code, media, and more. Explore practical tools and workflows that democratize advanced model capabilities, automate creative and analytical tasks, and enable rapid prototyping and deployment.

<div class="grid cards" markdown>

- **LLMs for Everyone (Ollama)** :material-robot:
	
    ---

	Run large language models locally for private, fast, and customizable text generation, summarization, and Q&A.

	[:material-arrow-right-circle: **Try Ollama LLMs →**](#ollama-llms)

- **ChatGPT for Everyone (OpenWebUI)** :material-chat:
	
    ---
	
    Chat with advanced AI models in your browser—no API keys required. Supports multi-model, multi-user, and plugin extensions.

	[:material-arrow-right-circle: **Open ChatGPT UI →**](#openwebui-chatgpt)

- **Stable Diffusion for Multimedia (ComfyUI)** :material-image:
	
    ---
	
    Generate images, art, and media with state-of-the-art diffusion models using a visual workflow builder.

	[:material-arrow-right-circle: **Launch ComfyUI →**](#stable-diffusion-comfyui)

- **Code Copilots (JIRA → Git → Cloud)** :material-code-tags:
	
    ---
	
    Automate code delivery from ticket to deployment in hours, not sprints. AI copilots for planning, coding, and cloud ops.

	[:material-arrow-right-circle: **See Code Copilot Demo →**](#code-copilots)

- **Deep Research Tools (Why-Whatbot)** :material-book-open:
	
    ---
	
    Generate dynamic research ebooks and reports on any topic, with citations and interactive exploration.

	[:material-arrow-right-circle: **Try Why-Whatbot →**](#deep-research-tools)

- **Search Assistant** :material-card-search:
	
    ---
	
    Elicit hidden insights and context with a generative search assistant that goes beyond keywords.

	[:material-arrow-right-circle: **Use Search Assistant →**](#search-assistant)

- **PowerPoint Agent** :material-presentation:
	
    ---
	
    Instantly generate 10-second slide decks from briefs or topics—perfect for rapid presentations.

	[:material-arrow-right-circle: **Generate Slides →**](#powerpoint-agent)

- **Flowise (RAG Canvas Builder)** :simple-xyflow:
	
    ---
	
    Build and deploy retrieval-augmented generation (RAG) agents visually with a drag-and-drop canvas.

	[:material-arrow-right-circle: **Open Flowise →**](#flowise-rag-builder)

- **Deepfake Generation** :material-face-recognition:
	
    ---
	
    Create realistic video deepfakes (e.g., Trump speaking MLK’s speech) for research and media analysis.

	[:material-arrow-right-circle: **Try Deepfake Demo →**](#deepfake-generation)

- **Demand Letter Parsing (Insurance)** :material-file-document:
	
    ---
	
    Extract and structure entities from insurance demand letters (PDFs) to flag and contest payout requests.

	[:material-arrow-right-circle: **Parse Demand Letters →**](#demand-letter-parsing)

- **Data Cataloging Agent** :material-database:
	
    ---
	
    Deep probe data tables and warehouses, auto-generate annotations and documentation like a human steward.

	[:material-arrow-right-circle: **Catalog Data →**](#data-cataloging-agent)

- **SQL Assistant** :material-table:
	
    ---
	
    Query data warehouses using natural language—get instant SQL and results, no manual coding required.

	[:material-arrow-right-circle: **Ask SQL Assistant →**](#sql-assistant)

</div>

---

## Ollama LLMs {\#ollama-llms}

Ollama lets you run powerful open-source large language models (LLMs) locally, with no cloud dependencies. You can generate text, summarize documents, answer questions, and produce structured outputs—all with privacy and speed. Ollama supports a wide range of models, including multimodal and instruction-tuned variants.

[Learn more about Ollama](https://ollama.com/){:target="_blank"}

**Example Shell Commands**

```bash
# List available models
ollama ls

# Pull a multimodal model (Qwen2.5vl:7b)
ollama pull qwen2.5vl:7b

# Run a model interactively
ollama run qwen2.5vl:7b

# Make an API call to the local Ollama server
curl -X POST http://localhost:11434/api/chat -H "Content-Type: application/json" -d '{
  "model": "qwen2.5vl:7b",
  "messages": [
    { "role": "user", "content": "What is the capital of France?" }
  ]
}'
```

**Example Python Usage (with llama_index)**

You can use Ollama programmatically for advanced tasks, including structured output and context management:

```python
from llama_index.llms.ollama import Ollama
from llama_index.core.llms import ChatMessage
from llama_index.core.bridge.pydantic import BaseModel

class TranslationRequest(BaseModel):
    text: str
    source_language: str
    target_language: str

class TranslationResponse(BaseModel):
    translated_text: str
    detected_language: str

llm = Ollama(
    model="qwen2.5vl:7b",
    request_timeout=120.0,
    context_window=4096,
)

sllm = llm.as_structured_llm(TranslationResponse)

request = TranslationRequest(
    text="वंदे मातरम्!",
    source_language="Hindi",
    target_language="English"
)

response = sllm.chat([
    ChatMessage(role="user", content=f"Translate the following text from {request.source_language} to {request.target_language}: `{request.text}`")
])
print(response.message.content)
```

Sample Output:
```json
{
  "translated_text": "Salutations to the Motherland!",
  "detected_language": "Hindi"
}
```

Ollama can return results as structured JSON, making it easy to integrate with downstream applications, automate workflows, or validate outputs. You can define your own schema and prompt the model to fill it, ensuring reliable, machine-readable results for tasks like entity extraction, document parsing, or knowledge graph construction.

**Try Ollama Translation Assistant**

Experience the <a href='http://{{ HOSTNAME | default("localhost") }}:8503/translation_assistant' target="_blank" rel="noopener noreferrer">**Ollama Translation Assistant**</a> live! Open the demo in your browser to explore seamless language translation powered by generative AI.

---

## OpenWebUI ChatGPT {\#openwebui-chatgpt}
OpenWebUI is an open-source, browser-based ChatGPT alternative designed for privacy and flexibility. It supports local deployments with Ollama, enabling airgapped operation and eliminating the need for API keys. Enjoy seamless conversations, multi-model support, plugin extensions, and multi-user chat -- all in a unified workspace.

[**Launch OpenWebUI Demo**](http://{{ HOSTNAME | default("localhost") }}:34000){:target="_blank"}. 

Use the following credentials to log in:

    - Username: `admin@example.com`
    - Password: `Passw0rd!`

*Sample Files*

You can use this file to create a knowledge [:material-download: *Resume.md*](assets/resume.md){:target="_blank"} and load it into a OpenWebUI custom model.

---

## Stable Diffusion (ComfyUI) {\#stable-diffusion-comfyui}

Create images and multimedia content using Stable Diffusion models with a visual workflow editor.
ComfyUI is a powerful, modular interface for Stable Diffusion and other generative models. It features a node-based workflow builder, allowing you to visually design complex image generation pipelines, experiment with model parameters, and automate batch processing. ComfyUI supports custom models, advanced prompt engineering, and integration with upscaling, inpainting, and control networks. Whether you're an artist, researcher, or developer, ComfyUI makes it easy to prototype, iterate, and deploy creative AI solutions.

*Sample Files*

You can import this Comfy workflow [:material-download: *flux_schnell.json*](assets/flux_schnell.json){:target="_blank"} and run to generate images. Before you do, you will open model_manager and download the Flux Schnell 1 models (17.2GB) download.

[**Launch ComfyUI Demo**](http://{{ HOSTNAME | default("localhost") }}:8188){:target="_blank"}

---

## Code Copilots {\#code-copilots}

Automate the journey from JIRA ticket to Git commit to cloud deployment. Accelerate development cycles with AI-powered copilots.
The Coding Assistant streamlines software development by integrating AI copilots into your workflow. It connects JIRA, Git, and cloud deployment tools, enabling automated code generation, review, and deployment from ticket creation to production—all in hours, not sprints. The assistant supports project planning, code authoring, and collaborative task management, making it ideal for teams seeking rapid iteration and delivery. Experience the full workflow by launching the Coding Assistant demo and accelerating your development process with generative AI.

[**Open Coding Assistant Demo**](http://{{ HOSTNAME | default("localhost") }}:8503/coding_assistant){:target="_blank"}

---

## Deep Research Tools (Whybot) {\#deep-research-tools}

Whybot is a inquisitive agent that probes deep into a research topic for the user. It -- on behalf of the user -- generates dynamic research that deeply traverses pre-programmed knowledge-bases (enterprise and LFM stores) to generate ebooks and reports, complete with citations, interactive Q&A, and visual knowledge mapping. Of the many things that LLMs can do, deep research is among the most impactful for enterprises, academia, and individuals.

[**Try the why-what-who-when-where-how bot**](http://{{ HOSTNAME | default("localhost") }}:3003?question=Name the great lakes of the US?){:target="_blank"}

---

## Search Assistant {\#search-assistant}

A generative search assistant that uncovers hidden insights and context beyond traditional search.

---

## PowerPoint Agent {\#powerpoint-agent}

Generate slide decks in seconds from briefs or topics—ideal for rapid presentations.

---

## Flowise RAG Builder {\#flowise-rag-builder}

Visually build and deploy retrieval-augmented generation (RAG) agents with a drag-and-drop canvas. Flowise lets you connect data sources, configure vector stores, and chain LLMs with custom logic—no coding required. Integrate documents, APIs, or databases, and design workflows for chatbots, search assistants, or automation. Export and deploy your RAG pipelines as APIs or web apps for instant access.

*Sample Files*

Import this workflow [:material-download: *ChatRAGFlow.json*](assets/ChatRAGFlow.json){:target="_blank"} and load it into Flowise.

[**Open Flowise Demo**](http://{{ HOSTNAME | default("localhost") }}:33000){:target="_blank"}

## Deepfake Generation {\#deepfake-generation}

Create realistic video deepfakes for research and analysis, such as historical speech reenactments.

---

## Demand Letter Parsing (Insurance) {\#demand-letter-parsing}

Extract structured entities from insurance demand letters to flag and contest payout requests. The Demand Letter Analyzer uses a multimodal large language model (`qwen2.5vl:7b` via [Ollama](https://ollama.com/library){:target="_blank"}) to extract structured information from insurance demand letters. You can upload PDF, image, or text files; the app combines visual and textual stimulus for accurate extraction. The model returns a detailed JSON object with key fields (claimant, claim amount, dates, evidence, etc.) and generates a professional acknowledgement letter for each valid demand. Results are displayed with page images, extracted fields, and the generated response letter—all in a streamlined interface for insurance adjusters. This tool streamlines insurance claim review, reduces manual data entry, and ensures consistent, professional responses.

*Sample Files* (use to test demand letter parsing)

 [:material-download: *Sample_Insurance_Demand_Letter_Property_Damage.png*](assets/Sample_Insurance_Demand_Letter_Property_Damage.png){:target="_blank"}

[**Launch Demand Letter Extraction Demo**](http://{{ HOSTNAME | default("localhost") }}:8503/demand_letters){:target="_blank"}

---

## Data Cataloging Agent {\#data-cataloging-agent}

Automatically annotate and document data tables and warehouses, improving data stewardship.

---

## SQL Assistant {\#sql-assistant}

Query data warehouses using natural language and get instant SQL and results.

---
