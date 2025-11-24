# AI Demo Central

A guided tour of Sensory AI, Generative AI, and Agentic AI

---

## 1. How to Use This Guide

This README is designed for non technical audiences who want to:

- Understand what each demo does in plain language.
- See why each capability matters for the business.
- Start the demos with a single command where possible.
- Browse screenshots that tell a story without reading code.

The flow is hierarchical:

1. Gallery overview (all four pillars, including Analytical AI).
2. Sensory AI deep dives (see, hear, read the world).
3. Generative AI deep dives (create text, media, code, and insights).
4. Agentic AI deep dives (orchestrate tasks and workflows).

Analytical AI appears in the overview gallery but is not expanded in detail here, in order to keep the focus on live experiential demos.

Wherever possible, exact `docker compose` commands are included to start services.

> If the reader is not the person running Docker, this guide can still serve as an “airplane book” that explains the capabilities while another operator runs the commands.

---

## 2. Gallery Overview: The Four Pillars

The portal home page is the single entry point.

```text
http://localhost:8500
````

Start or restart it with:

```bash
docker compose -f docker-compose.yml up -d --build landing
```

Once it is running, it can be opened in a browser to reveal a gallery of cards representing the four pillars of the platform.

<img src="screenshots/00_landing_page.png" alt="Portal home" style="max-width:80%; display:block; margin:0 auto;" />

### 2.1 Analytical AI (overview only)

Analytical AI covers classic machine learning over structured data:

* Forecasting (demand, revenue, risk).
* Scoring (propensity, churn, next best action).
* Cohort analysis and segmentation.
* Dashboards and enterprise search over tables.

In this release, Analytical AI is represented primarily in navigation and supporting documentation, rather than as the centerpiece of the live demos. It is often sufficient to note that structured machine learning is already well understood, and that differentiation in this demo suite comes from the next three pillars.

### 2.2 Sensory AI

Sensory AI systems extract meaning from images, videos, documents, and audio:

* Turning scanned documents into searchable text.
* Transcribing calls and meetings into notes and summaries.
* Tracking objects in video (for traffic, safety, operations).
* Capturing field data on a mobile device.

The sequence starts with Sensory AI demos, because they show AI perceiving the real world.

### 2.3 Generative AI

Generative AI systems create new content:

* Text: chat, summarization, translation, research.
* Media: images and video.
* Code: assistants that move from ticket to deployment.
* Slides and reports built from knowledge bases.

These demos showcase how large language models and diffusion models can amplify human work.

### 2.4 Agentic AI

Agentic AI systems do not just respond to prompts. They:

* Read and understand inputs.
* Plan multi step workflows.
* Call tools and APIs.
* Take actions with traceability and guardrails.

Agentic patterns appear inside several demos (Meeting AI, deep research, Flowise, demand letter parsing), and later sections show how these building blocks combine into cohesive agent flows.

---

## 3. Sensory AI Deep Dives

Sensory AI is the natural starting point for the demo story.

A concise framing line:

> “First, AI is taught to see, hear, and read the world responsibly. Once reality is perceived, insights and actions can follow with confidence.”

### 3.1 Sensory AI Demo Map

The following table acts as a quick mental map.

| Demo                                  | What it does                                                                            | How to start                                                                 | Where to open                    |
| ------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------- |
| Case Manager (AI at the Edge)         | Mobile app for capturing cases in the field (notes, voice, documents, photos, contacts) | Install APK on an Android device                                             | On the device, open Case Manager |
| Docling OCR & Document Parsing        | Browser based OCR and layout aware parsing for PDFs and images                          | `docker compose -f docker-compose.yml up -d docling`                         | `http://localhost:5001/ui/`      |
| Real Time Transcription (WhisperLive) | Live speech to text in the browser                                                      | `docker compose -f docker-compose.yml up -d whisperlive`                     | `http://localhost:8501`          |
| Meeting AI (Multimedia Intelligence)  | On device meeting assistant: diarization, transcripts, summaries                        | `docker compose -f docker-compose.yml up -d meeting_ai` (name may vary)      | `http://localhost:3880`          |
| Video Intelligence (Traffic Tracking) | Real time vehicle segmentation and tracking from video                                  | `docker compose -f docker-compose.yml up -d traffic_tracker` (name may vary) | Streamlit or app URL for tracker |

For non technical audiences, the emphasis can remain on outcomes rather than ports and implementation details.

---

### 3.2 AI at the Edge: Case Manager App

#### 3.2.1 Concept

Field staff rarely sit in front of a laptop. Typical activities include:

* Walking job sites.
* Inspecting assets.
* Meeting customers.
* Collecting messy, multi format information.

The Case Manager app gives each user a single “digital binder” per case, where all relevant information can be captured on the go and later fed into downstream AI systems.

Each case functions like a digital folder that can hold:

* Text notes.
* Voice memos.
* Scanned documents and file attachments.
* Contacts.
* Handwritten ink notes with recognition.
* Photos and other multimedia.

#### 3.2.2 Installation (non technical path)

Developer tools are not required if an APK has already been built.

1. Obtain the APK file, for example `case_manager_nov_4.apk` from the repository.
2. On an Android phone or tablet, copy or download the APK.
3. On the device, allow installation from “unknown apps” for the browser or file manager that will be used.
4. Tap the APK in the Downloads list or file manager.
5. Accept installation and required permissions (camera, microphone, storage, NFC if used).
6. Open the Case Manager icon once installation completes.

Relevant files in the `assets/` folder:

* [Case Manager APK](landing/docs/assets/case_manager_nov_4.apk)
* [Installation Guide for the Case Manager App (PDF)](landing/docs/assets/Installation%20Guide%20for%20the%20Case%20Manager%20App.pdf)
* [Usage Guide for the Case Manager App (PDF)](landing/docs/assets/Usage%20Guide%20for%20the%20Case%20Manager%20App.pdf)

#### 3.2.3 Key capabilities

When the app opens, a “case” appears as the central unit of organization.

Within a case it is possible to:

* Create text notes for quick thoughts.
* Record voice memos for interviews or instructions.
* Scan documents such as business cards, memos, or blueprints.
* Import or create contacts related to the case.
* Draw ink notes with a finger or stylus and let the app recognize handwriting.
* Capture photos or videos and attach them to the case.
* Export the entire case as JSON for downstream systems.
* Share contact details via NFC, AirDrop, or email.

This can be positioned as “sensory on the edge”: the device collects rich data that can later be processed by Sensory AI, Generative AI, and Analytical AI components.

---

### 3.3 Docling OCR & Document Parsing

#### 3.3.1 Concept

Many organizations are full of legacy PDFs, scans, and images that behave like “dark data”. Docling translates these into structured, searchable content.

Users can:

* Drag and drop PDF, image, or Office files into the browser.
* Visually inspect OCR output.
* Review extracted text, layout, and tables.
* Send the same extraction logic to downstream systems via an API.

Sample documents in the `assets/` folder:

* [Sample visual document (PNG)](landing/docs/assets/sample_visual.png)
* [Visual parsing example (PDF)](landing/docs/assets/visual_parsing.pdf)

#### 3.3.2 Starting the service

```bash
docker compose -f docker-compose.yml up -d docling
```

Open the UI:

```text
http://localhost:5001/ui/
```

#### 3.3.3 Screenshots

Main Docling UI with upload area and preview panel:

<img src="screenshots/23_docling_ui.png" alt="Docling UI" style="max-width:80%; display:block; margin:0 auto;" />

Extracted contents for a specific document, with visible layout and text:

<img src="screenshots/24_docling_ui.png" alt="Docling extraction" style="max-width:80%; display:block; margin:0 auto;" />

API documentation showing available routes for integration:

<img src="screenshots/25_docling_api.png" alt="Docling API" style="max-width:80%; display:block; margin:0 auto;" />

---

### 3.4 Real Time Transcription (WhisperLive)

#### 3.4.1 Concept

Enterprises run on conversations: sales calls, support lines, interviews, and internal meetings. Much of that value disappears because it is not captured.

Real Time Transcription turns live speech into text on the fly in the browser.

#### 3.4.2 Starting the service

```bash
docker compose -f docker-compose.yml up -d whisperlive
```

Open the UI:

```text
http://localhost:8501
```

If the demo runs from a jump host or remote server and browser microphone permissions are required, SSH tunnels can be configured as described in the Sensory AI documentation. For local demonstrations, the URL can be opened directly.

#### 3.4.3 Screenshots

Live transcription canvas, with text appearing as speech is detected:

<img src="screenshots/31_near_realtime_transcription.png" alt="Near real time transcription" style="max-width:80%; display:block; margin:0 auto;" />

Foreign language example, demonstrating language detection and multilingual capability:

<img src="screenshots/32_near_realtime_transcription_foreign_language.png" alt="Foreign language transcription" style="max-width:80%; display:block; margin:0 auto;" />

Browser extension installation for toolbar based access (Chrome or Edge):

<img src="screenshots/32_chrome_edge_extension_installation.png" alt="Extension install" style="max-width:80%; display:block; margin:0 auto;" />

---

### 3.5 Meeting AI (Multimedia Intelligence)

#### 3.5.1 Concept

Rather than taking manual notes in meetings, participants can:

* Record audio or screen captures.
* Allow Meeting AI to separate speakers.
* Generate transcripts and structured summaries.
* Keep processing local for privacy.

Meeting AI is a local web application that accepts recorded meetings and produces:

* High quality transcripts.
* Speaker diarization and labels.
* Topic centric summaries.
* Suggested action items.

Sample meeting recordings in the `assets/` folder:

* [DeGrasse.webm](landing/docs/assets/DeGrasse.webm)
* [Goodall.webm](landing/docs/assets/Goodall.webm)
* [Teresa.webm](landing/docs/assets/Teresa.webm)

#### 3.5.2 Starting the service

In `docker-compose.yml`, the service backing this UI is typically named `meeting_ai`:

```bash
docker compose -f docker-compose.yml up -d meeting_ai
```

Open the UI:

```text
http://localhost:3880
```

#### 3.5.3 Screenshots

Recording or uploading a meeting or screen capture:

<img src="screenshots/41_meeting_ai_record_screencast.png" alt="Record screencast" style="max-width:80%; display:block; margin:0 auto;" />

Per speaker segmentation and labels:

<img src="screenshots/42_meeting_ai_speaker_diarization.png" alt="Speaker diarization" style="max-width:80%; display:block; margin:0 auto;" />

Detailed per speaker transcript:

<img src="screenshots/43_meeting_ai_speaker_transcription.png" alt="Speaker transcription" style="max-width:80%; display:block; margin:0 auto;" />

Summaries derived from the transcript, including topics and actions:

<img src="screenshots/45_meeting_ai_summarization_from_transcript.png" alt="Summarization" style="max-width:80%; display:block; margin:0 auto;" />

On device summarization for privacy sensitive or air gapped environments:

<img src="screenshots/47_meeting_ai_summarization_on_device.png" alt="On device summarization" style="max-width:80%; display:block; margin:0 auto;" />

---

### 3.6 Video Intelligence (Traffic Tracking)

#### 3.6.1 Concept

In many operations contexts, individual frames of video are less important than counts, patterns, bottlenecks, and anomalies.

The video tracking demo illustrates how the system can be used to:

* Detect and segment vehicles in a live or recorded feed.
* Track each object with a stable identifier.
* Build analytics on top of those tracks (volume, dwell time, lane usage).

Sample traffic videos in the `assets/` folder:

* [highway.mp4](landing/docs/assets/highway.mp4)
* [highway_processed_output.mp4](landing/docs/assets/highway_processed_output.mp4)

#### 3.6.2 Starting the service

The tracker is typically implemented as a small web app (often Streamlit) backed by a YOLO segmentation model. In `docker-compose.yml`, look for a service referencing YOLO or traffic tracking and start it, for example:

```bash
docker compose -f docker-compose.yml up -d traffic_tracker
```

Then open the configured URL and load the sample highway video.

#### 3.6.3 Screenshots

Live tracking over a traffic video, with bounding boxes or masks:

<img src="screenshots/50_streamlit_car_tracker_in_realtime_traffic_video.png" alt="Car tracker" style="max-width:80%; display:block; margin:0 auto;" />

Segmentation masks that clearly separate each vehicle from the background:

<img src="screenshots/51_yolo_tracking_car_masks_realtime.png" alt="YOLO masks" style="max-width:80%; display:block; margin:0 auto;" />

Analytics oriented overlays showing IDs and trajectories:

<img src="screenshots/53_yolo_tracking_car_masks_realtime_output.png" alt="Tracking output" style="max-width:80%; display:block; margin:0 auto;" />

---

## 4. Generative AI Deep Dives

Once perception is established through Sensory AI, the narrative progresses to value creation: text, media, code, and research.

A simple framing line:

> “Now that the system can see and hear what is happening, it can be asked to summarize, translate, ideate, and even propose software changes.”

### 4.1 Generative AI Demo Map

| Demo                       | What it does                                                       | Typical URL                                                                                                   |
| -------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| Ollama LLMs                | Runs open source LLMs locally for chat, Q&A, and structured output | API often at `http://localhost:11434`; translation assistant at `http://localhost:8503/translation_assistant` |
| OpenWebUI                  | ChatGPT style interface over local or remote models                | `http://localhost:34000`                                                                                      |
| ComfyUI (Stable Diffusion) | Node based canvas for image and multimedia generation              | `http://localhost:8188`                                                                                       |
| Coding Assistant           | Moves from JIRA ticket to Git and deployment with AI help          | `http://localhost:8503/coding_assistant`                                                                      |
| Whybot / Deep Research     | Multi step research agent (why, what, who, when, where, how)       | `http://localhost:3003`                                                                                       |
| Search Assistant           | Generative search interface over complex data                      | Environment specific                                                                                          |
| PowerPoint Agent           | Produces “10 second” slide decks inside PowerPoint                 | Appears as a ribbon add-in                                                                                    |
| Flowise RAG Builder        | Visual canvas for retrieval augmented agents                       | `http://localhost:33000`                                                                                      |
| Demand Letter Parsing      | Multimodal extraction and response for insurance demand letters    | `http://localhost:8503/demand_letters`                                                                        |
| Data Cataloging Agent      | Automatically annotates tables and data warehouses                 | Part of data and search stack                                                                                 |
| SQL Assistant              | Conversational interface that produces SQL and results             | Part of analytics and catalog stack                                                                           |

The exact services and ports are defined in `docker-compose.yml`. A common pattern for bringing up several generative components together might look like:

```bash
# Example only. Adjust service names to match docker-compose.yml.
docker compose -f docker-compose.yml up -d ollama openwebui comfyui flowise streamlit_apps
```

---

### 4.2 Ollama: LLMs for Everyone

#### 4.2.1 Concept

Ollama hosts large language models on enterprise infrastructure, which enables:

* Independence from external APIs.
* Control over data privacy and retention.
* Flexibility to adopt new open source models quickly.

Typical use cases include:

* Chat and Q&A over internal content.
* Summarization and rewriting.
* Translation between languages.
* Structured extraction into JSON for downstream systems.

#### 4.2.2 Screenshots

Concept slide summarizing private, local models:

<img src="screenshots/60_Ollama_For_Everyone.png" alt="Ollama for everyone" style="max-width:80%; display:block; margin:0 auto;" />

Casting the model into human like “roles” (advisor, analyst, translator):

<img src="screenshots/61_Ollama_Serving_Human_Roles.png" alt="Human roles" style="max-width:80%; display:block; margin:0 auto;" />

Focused translation scenario:

<img src="screenshots/62_Ollama_Serving_Translator_Role.png" alt="Translator role" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.3 OpenWebUI: ChatGPT Style Experience On Premise

#### 4.3.1 Concept

OpenWebUI is a browser based interface that looks and feels like ChatGPT but runs on enterprise infrastructure. It provides:

* Multi model chat (for example, switching between different Ollama models).
* Persistent conversations.
* Memory and history.
* Support for knowledge bases and prompt libraries.

A sample resume used as a knowledge file is included in `assets/`:

* [resume.md](landing/docs/assets/resume.md)

#### 4.3.2 Screenshots

Main chat interface, with a familiar ChatGPT style experience:

<img src="screenshots/63_OpenWebUI_ChatGPT_Clone.png" alt="ChatGPT clone" style="max-width:80%; display:block; margin:0 auto;" />

Multi turn conversations with saved outcomes:

<img src="screenshots/64_OpenWebUI_Multiturn_MemoryChatOutcomes.png" alt="Multi turn and memory" style="max-width:80%; display:block; margin:0 auto;" />

Management of complex knowledge agents:

<img src="screenshots/65_ManageComplexKnowledgeAgents_OpenWebUI.png" alt="Knowledge agents" style="max-width:80%; display:block; margin:0 auto;" />

Custom prompt shortcuts functioning as a lightweight prompt library:

<img src="screenshots/66_CreateCustomPromptShortcuts_PoorMansPromptLibrary.png" alt="Prompt shortcuts" style="max-width:80%; display:block; margin:0 auto;" />

Enterprise knowledge bases, including connectors such as SharePoint:

<img src="screenshots/67_Create_Enterprise_Knowledge_Bases_Including_Sharepoint_O.png" alt="Enterprise knowledge bases" style="max-width:80%; display:block; margin:0 auto;" />

Custom models seeded with enterprise knowledge:

<img src="screenshots/68_Create_Custom_Models_Seed_Agents_with_Knowledge.png" alt="Custom models and seed agents" style="max-width:80%; display:block; margin:0 auto;" />

Multimodal inputs and reinforcement feedback:

<img src="screenshots/69_Multimodal_Inputs_Reinforcement_Feedback.png" alt="Multimodal feedback" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.4 ComfyUI: Visual Multimedia Generation

#### 4.4.1 Concept

ComfyUI brings generative media workflows into a visual canvas. Instead of writing code, users can:

* Drag and drop nodes.
* Connect models and processors.
* Tweak parameters.
* Generate images or video variations.

A sample workflow is provided in `assets/`:

* [flux_schnell.json](landing/docs/assets/flux_schnell.json)

This file can be imported into ComfyUI and executed once the corresponding model weights are downloaded.

#### 4.4.2 Screenshots

Starter canvas templates that can be loaded and customized:

<img src="screenshots/71_wysiwyg_comfy_canvas_temlates.png" alt="Canvas templates" style="max-width:80%; display:block; margin:0 auto;" />

Graphical model manager and module installation:

<img src="screenshots/72_graphical_module_model_comfy_installs.png" alt="Model manager" style="max-width:80%; display:block; margin:0 auto;" />

Assembled pipelines connecting prompts, models, and outputs:

<img src="screenshots/73_assembly_comfy_pipeline_canvas.png" alt="Pipeline assembly" style="max-width:80%; display:block; margin:0 auto;" />

Generated multimedia outputs:

<img src="screenshots/74_generate_realistic_multimedia_images_videos.png" alt="Generated multimedia" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.5 Coding Assistant: From Ticket to Cloud

#### 4.5.1 Concept

Software delivery is often slowed by handoffs:

* Product management writes requirements.
* Engineers translate those into code.
* DevOps teams handle deployment.

The Coding Assistant shortens this loop by:

* Reading tickets from systems such as JIRA.
* Proposing implementation plans.
* Drafting code.
* Assisting with deployment scripts.

#### 4.5.2 Screenshots

End to end flow from ticket to deployed code in hours rather than sprints:

<img src="screenshots/80_coding_assistant_from_code_to_cloud_in_hours_not_sprints.png" alt="Code to cloud" style="max-width:80%; display:block; margin:0 auto;" />

Planning, estimation, and fulfillment across roles:

<img src="screenshots/81_coding_assistant_from_planning_to_fulfillment.png" alt="Planning to fulfillment" style="max-width:80%; display:block; margin:0 auto;" />

Consistent archetypes and multi turn steering of the assistant:

<img src="screenshots/82_consistent_code_archetypes_and_multiturn_steering.png" alt="Code archetypes" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.6 Deep Research (Whybot and Search Companion)

#### 4.6.1 Concept

Traditional search yields links, whereas deep research tools deliver synthesized understanding.

The deep research demos illustrate an agent that:

* Breaks a question into sub questions.
* Iteratively explores relevant sources.
* Consolidates findings into structured reports.
* Supports follow up questions and deeper probes.

#### 4.6.2 Screenshots

“Pearl growing” infobot progressively building a richer picture of a topic:

<img src="screenshots/83_deep_research_pearl_growing_infobot.png" alt="Pearl growing research" style="max-width:80%; display:block; margin:0 auto;" />

Multi step probing into why, what, how, when, who, and where:

<img src="screenshots/84_progressively_probe_deeper_deeper_why_what_how_when_who_where.png" alt="Progressive probing" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.7 PowerPoint Agent: Ten-Second Slides

#### 4.7.1 Concept

Executives and managers spend significant time preparing slides. The PowerPoint Agent:

* Runs directly inside PowerPoint as an add-in.
* Accepts a short brief or topic.
* Generates slides in seconds.
* Uses organizational knowledge bases for content.

#### 4.7.2 Screenshots

Installation of the add-in into the Office suite:

<img src="screenshots/85_PowerpointAddin_Install.png" alt="Add in install" style="max-width:80%; display:block; margin:0 auto;" />

Add-in visible inside PowerPoint:

<img src="screenshots/86_Powerpoint_Addin_Embedded_In_OfficeSuite.png" alt="Add in in Office" style="max-width:80%; display:block; margin:0 auto;" />

Configuration window for setting up the agent and connecting knowledge:

<img src="screenshots/87_Configuration_and_Soliciting_10_second_slides_agent.png" alt="Configuration" style="max-width:80%; display:block; margin:0 auto;" />

Slide deck generated from deep research over custom knowledge:

<img src="screenshots/88_10_Second_slides_From_deep_research_on_custom_knowledge.png" alt="Generated ten-second slides" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.8 Semantic Search and Data Cataloging

#### 4.8.1 Concept

Many organizations are flooded with data but starved for context. Common challenges include:

* Tables with little or no metadata.
* Difficulty discovering which dataset answers which question.

The semantic search and data cataloging stack addresses this by:

* Allowing LLMs to inspect and annotate tables.
* Building a living data catalog.
* Enabling natural language search and SQL generation.

#### 4.8.2 Screenshots

Why brittle keyword search is not enough:

<img src="screenshots/90_traditional_search_is_broken_brittle.png" alt="Traditional search is brittle" style="max-width:80%; display:block; margin:0 auto;" />

LLMs introducing deep domain expertise into search:

<img src="screenshots/91_LLMs_Apply_Their_Deep_Domain_Expertise_To_Deliver_Semantic_Search.png" alt="Semantic search" style="max-width:80%; display:block; margin:0 auto;" />

Data without sufficient metadata:

<img src="screenshots/92_a_everyone_has_data_but_no_metadata_they_have_no_time_to_annotate.png" alt="No metadata" style="max-width:80%; display:block; margin:0 auto;" />

LLMs acting as stewards for data cataloging:

<img src="screenshots/93_let_llms_deep_inspect_and_take_over_stewarding_data_cataloging.png" alt="LLMs as stewards" style="max-width:80%; display:block; margin:0 auto;" />

Annotated datasets enabling natural language insights:

<img src="screenshots/94_Annotated_Datasets_Attributes_Records_Allow_Natural_language_insights.png" alt="Annotated datasets" style="max-width:80%; display:block; margin:0 auto;" />

Annotated catalogs supporting structured queries from English and deep tool usage:

<img src="screenshots/95_Annotated_Catalogs_Allow_Structured_Query_From_English_and_Deep_MCP_Insights.png" alt="Annotated catalogs" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.9 Flowise: Visual RAG Builder

#### 4.9.1 Concept

Flowise acts as an orchestration canvas. It enables:

* Drag and drop composition of retrievers, models, and tools.
* Visual definition of control flow.
* Inline testing of prompts and flows.
* Deployment as APIs or web apps.

A sample Flowise workflow in the `assets/` folder:

* [ChatRAGFlow.json](landing/docs/assets/ChatRAGFlow.json)

This file can be imported into Flowise to create a retrieval-augmented chatbot.

#### 4.9.2 Screenshots

Workflow composer showing how components connect:

<img src="screenshots/96_flowise_workflow_composer.png" alt="Workflow composer" style="max-width:80%; display:block; margin:0 auto;" />

WYSIWYG representation of flows:

<img src="screenshots/97_flowise_workflows_with_wysiwyg.png" alt="WYSIWYG flows" style="max-width:80%; display:block; margin:0 auto;" />

Integrated prompt testing node:

<img src="screenshots/97_integrated_prompt_testing_flowise.png" alt="Prompt testing" style="max-width:80%; display:block; margin:0 auto;" />

Design and deployment views for in-situ experimentation:

<img src="screenshots/98_design_and_deploy_insitu.png" alt="Design and deploy" style="max-width:80%; display:block; margin:0 auto;" />

Deployment to existing endpoints while reusing infrastructure:

<img src="screenshots/99_deploy_to_existing_endpoints.png" alt="Deploy to endpoints" style="max-width:80%; display:block; margin:0 auto;" />

---

### 4.10 Demand Letter Parsing (Insurance)

#### 4.10.1 Concept

Insurance adjusters receive complex demand letters that mix text, tables, and images. Manual reading, extraction, and response drafting is time consuming and can be inconsistent.

The demand letter parsing demo:

* Accepts demand letters as PDF, image, or text.
* Uses a multimodal LLM to extract key entities (claimant, amounts, dates, evidence).
* Generates a professional acknowledgement or rebuttal letter.
* Displays structured JSON plus the generated response.

Sample input in `assets/`:

* [Sample_Insurance_Demand_Letter_Property_Damage.png](landing/docs/assets/Sample_Insurance_Demand_Letter_Property_Damage.png)

#### 4.10.2 Screenshots

Initial parsing of an uploaded demand letter:

<img src="screenshots/a00_demand_letter_parse_on_demand.png" alt="Demand letter parse on demand" style="max-width:80%; display:block; margin:0 auto;" />

Parsed structure and suggested response letter:

<img src="screenshots/a00_demand_letter_parsed_and_rebutted.png" alt="Parsed and rebutted" style="max-width:80%; display:block; margin:0 auto;" />

Lexical intelligence extracted from the document:

<img src="screenshots/a01_demand_letter_lexical_intelligence_extracted.png" alt="Lexical intelligence" style="max-width:80%; display:block; margin:0 auto;" />

---

## 5. Agentic AI: From Capabilities to Workflows

Agentic AI is not a single application. It is a way of composing perception and generation into reliable workflows that act.

Conceptually, an agent:

1. Observes.
2. Thinks.
3. Plans.
4. Acts.
5. Learns from feedback.

### 5.1 Design considerations

Agentic capabilities benefit from clear guardrails:

* Every decision is traceable with logs and audit trails.
* Actions that change systems can be gated behind approvals.
* Workflows are resilient, with retries, fallbacks, and timeouts.
* Permissions and scopes are enforced at each tool boundary.

These patterns build on the demos already described:

* Meeting AI behaves as an agent that reads audio, plans diarization, then produces transcripts and summaries.
* Deep research behaves as an agent that repeatedly asks internal sub-questions while exploring a topic.
* Flowise is explicitly an agent builder, wiring perception, retrieval, and action nodes.
* Demand letter parsing is an agent specialized for a single document-centric workflow.

### 5.2 Example agent flows

#### 5.2.1 Customer case lifecycle

1. A field agent uses the Case Manager app to capture photos, voice notes, and signed documents for a new case.
2. Documents from the case are processed through Docling for OCR and structuring.
3. A Meeting AI session with the customer is recorded and summarized.
4. A Flowise-built agent orchestrates:

   * Retrieval of relevant policy documents.
   * Use of an Ollama-backed LLM to compare the case to policy.
   * Drafting of a response using the demand letter agent where appropriate.
5. The PowerPoint agent generates a concise internal briefing deck for review.

#### 5.2.2 Data stewardship agent

1. Tables and datasets are profiled by a background process.
2. A data cataloging agent uses LLMs to infer column meanings and relationships.
3. The agent writes annotations into the catalog.
4. The SQL assistant and search assistant leverage these annotations to answer natural language questions such as “Show churn by region over the last six months.”

In both examples, the agent is a composition of capabilities described earlier: perception (Sensory AI), generation (Generative AI), and action (Agentic orchestration).

---

## 6. Quick Docker Compose Reference

This section acts as a checklist for the most common services when preparing a demo.

> Adjust service names to match the `docker-compose.yml` file in the environment. The examples illustrate typical patterns.

### 6.1 Portal and Navigation

```bash
# Portal landing page
docker compose -f docker-compose.yml up -d --build landing
```

### 6.2 Sensory AI

```bash
# Docling OCR and document parsing
docker compose -f docker-compose.yml up -d docling

# Real time speech to text (WhisperLive)
docker compose -f docker-compose.yml up -d whisperlive

# Meeting AI (service name)
docker compose -f docker-compose.yml up -d meeting_ai

# Video intelligence / traffic tracker (service name)
docker compose -f docker-compose.yml up -d cartracker
```

### 6.3 Generative and Agentic Stack (examples)

```bash
# Core model and chat stack (example)
docker compose -f docker-compose.yml up -d ollama openwebui

# Visual RAG and orchestration (example)
docker compose -f docker-compose.yml up -d flowise

# Media generation (example)
docker compose -f docker-compose.yml up -d comfyui

# Streamlit-based assistants: coding, demand letters, translation (example)
docker compose -f docker-compose.yml up -d streamlit_apps
```
```