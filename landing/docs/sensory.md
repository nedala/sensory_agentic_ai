# Sensory AI

Systems that extract meaning from **images, videos, documents, and audio**.

<div class="grid cards" markdown>

-   **AI at the Edge** :material-cellphone:{ .md-icon }

    ---
    Empowering users with on-device AI for real-time analytics and responsible customer care.

    [:material-arrow-right-circle: **Install Case Manager App →**](#ai-at-the-edge)

-   **Docling OCR & Document Parsing** :material-file-search-outline:{ .md-icon }

    ---
    Layout-aware OCR, table extraction, and multi-format parsing (PDF, images, Office docs).

    [:material-arrow-right-circle: **Open Docling Demo →**](#docling-document-parsing)

-   **Speech-to-Text** :material-microphone:{ .md-icon }

    ---
    Real-time language detection, transcription, and translation using open-source models for accuracy and speed.

    [:material-arrow-right-circle: **Launch Speech Demo →**](#real-time-transcription)

-   **Multimedia Intelligence** :material-waveform:{ .md-icon }

    ---

    A privacy-preserving audio-video content analyzer, such as the Meeting AI Agent, with advanced semantic, sense-making, linguistic, visual, and aural capabilities.

    [:material-arrow-right-circle: **Open Meeting AI →**](#multimedia-intelligence)

-   **Video Intelligence** :material-movie:{ .md-icon }

    ---
    Frame extraction, scene understanding, object segmentation, and object tracking.

    [:material-arrow-right-circle: **Launch Video Demo →**](#video-intelligence)

</div>

---

## Docling Document Parsing {\#docling-document-parsing}

Try the live <a href="http://{{ HOSTNAME | default("localhost") }}:5001/ui/" target="_blank" rel="noopener noreferrer">Docling UI at http://{{ HOSTNAME | default("localhost") }}:5001/ui/</a> to parse PDFs, scanned images, and Office files. Upload the sample files listed above (sample_visual.png or visual_parsing.pdf) or drag-and-drop your own documents.

*Sample Files*

 [:material-download: *sample_visual.png*](assets/sample_visual.png){:target="_blank"} and [:material-download: *visual_parsing.pdf*](assets/visual_parsing.pdf){:target="_blank"}

---

## Real-Time Transcription {\#real-time-transcription}

A small <a href="http://localhost:18501" target="_blank" rel="noopener noreferrer">browser-based speech demo at http://localhost:18501</a> that listens in real-time to the microphone and shows detected language, live karaoke-style partials, and a scrolling history of final lines. To run the demo (and establish trust to capture the microphone), create a local SSH tunnel to {{ HOSTNAME | default("localhost") }}.

```bash
# Set the UI proxy to allow for microphone access
ssh -L 18501:localhost:18501 seshu@{{ HOSTNAME | default("dockerhost") }}
```

```bash
# Set the websocket proxy to allow for trusted translation/transcription access
ssh -L 9090:localhost:9090 seshu@{{ HOSTNAME | default("dockerhost") }}
```

---

## Multimedia Intelligence {\#multimedia-intelligence}

<a href="http://{{ HOSTNAME | default("localhost") }}:3880" target="_blank" rel="noopener noreferrer">Meeting AI  at http://{{ HOSTNAME | default("localhost") }}:3880</a> is a privacy-preserving, on-device meeting assistant that processes recorded meetings, performs high-quality speech diarization, generates transcripts, and provides structured meeting summaries using local LLMs via Ollama.

The application runs entirely offline, supports screen-recording input, and produces accurate multi-speaker transcripts and inferred participant identities.

*Sample Files* (use the following files to test meeting assistant)

 - [:material-download: *DeGrasse.webm*](assets/DeGrasse.webm){:target="_blank"},  [:material-download: *Goodall.webm*](assets/Goodall.webm){:target="_blank"} and [:material-download: *Teresa.webm*](assets/Teresa.webm){:target="_blank"}

---


## Video Intelligence {\#video-intelligence}

Lightweight real-time video tracking demo that detects, segments, and tracks cars (YOLO masks), assigns stable tracker IDs. The demo highlights segmentation, tracking, labeling, real-time GPU-accelerated processing. Supports MP4, MOV, AVI.

*Sample File* (use the following video to test traffic tracking)

 - [:material-download: *highway.mp4*](assets/highway.mp4){:target="_blank"}

---

## AI at the Edge {\#ai-at-the-edge}

A Flutter-based case management app for capturing and organizing cases with inking notes, voice memos, photos, and text notes. Includes contact sharing and case export capabilities.

Please download and install [:material-download: *case_manager_nov_4.apk*](case_manager_nov_4.apk){:target="_blank"}

Features

- Case Management: create, edit, delete cases.
- Inking Notes: draw on an ink canvas with live recognition (Google ML Kit Digital Ink).
- Voice Memos: record and attach audio to a case.
- Pictures: add, view, delete photos per case.
- Text Notes: create and manage textual notes.
- Share My Contact: share your contact via native share.
- Export Case: export case data (JSON) for sharing or backup.
