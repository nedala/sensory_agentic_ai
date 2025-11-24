# Pearl Growing Deep Research (Whybot)

Pearl Growing Deep Research (formerly Whybot) is an interactive tool for deep, structured exploration of questions using large language models (LLMs). It helps you uncover fundamental truths by generating and organizing follow-up questions and answers in a mindmap-like interface.

## Features
- Interactive Q&A tree/mindmap with expandable/collapsible nodes
- Each node contains both a question and its LLM-generated answer
- Markdown support for answers
- Export options: NetworkX (Python), HTML, SVG mindmap
- Edit and regenerate any question node
- Local LLM support (Ollama, etc.)
- Persona-driven question generation (Researcher, Hacker News, Toddler, etc.)
- Modern, paper-like UI with focus/selection highlighting

## Credits
- Original project: Whybot by John Qian and Vish Rajiv
- Local LLM adaptation: Seshu Edala ([https://seshu.gnyan.ai:8443/](https://seshu.gnyan.ai:8443/))

## Getting Started
1. **Install dependencies:**
   ```sh
   npm install
   # or
   yarn
   ```
2. **Start the development server:**
   ```sh
   npm run dev
   # or
   yarn dev
   ```
3. **Open your browser:**
   Visit [http://localhost:3003](http://localhost:3003)

## Export & Integration
- Export your Q&A tree as NetworkX Python, HTML, or SVG mindmap from the UI.
- Markdown is supported in answers for rich formatting.
