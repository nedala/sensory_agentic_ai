import streamlit as st
import os
import json
import uuid
import shutil
import zipfile
from pathlib import Path
import pandas as pd

from llama_index.llms.ollama import Ollama
from llama_index.core.llms import (
    ChatMessage,
    TextBlock,
    MessageRole
)
from llama_index.core.bridge.pydantic import BaseModel, Field


# =====================================================================
# STREAMLIT CONFIG
# =====================================================================
st.set_page_config(page_title="Coding Assistant", layout="wide")


# =====================================================================
# LLM SETUP — Qwen3-Coder 30B
# =====================================================================
MODEL_NAME = os.environ.get("MODEL_NAME", "qwen3-coder:30b")
BASE_URL = os.environ.get("BASE_URL", "http://localhost:11434")

llm = Ollama(
    model=MODEL_NAME,
    base_url=BASE_URL,
    request_timeout=45,
    context_window=2048,
    temperature=0.0,
)


# =====================================================================
# STRUCTURED SCHEMAS
# =====================================================================
class ProjectPlan(BaseModel):
    language: str
    summary: str
    architecture_overview: str
    requirements_summary: str
    archive_zip_filename: str = Field(default="project.zip")


class FileSpec(BaseModel):
    filename: str
    directory: str
    purpose: str
    functions: list[str] | None


class FileLayout(BaseModel):
    files: list[FileSpec]


class FileSummary(BaseModel):
    summary: str


plan_llm = llm.as_structured_llm(ProjectPlan)
layout_llm = llm.as_structured_llm(FileLayout)
summary_llm = llm.as_structured_llm(FileSummary)


# =====================================================================
# PROMPTS
# =====================================================================

PLAN_PROMPT = """
You are an expert software architect.

User project description:
---
{description}
---

Return JSON with:
- language
- summary
- architecture_overview
- requirements_summary
- archive_zip_filename (a concise descriptive file name to compress source artifacts into a zip file with extension, e.g., my_app.zip)

Return ONLY valid JSON.
"""

LAYOUT_PROMPT = """
You are an expert software architect.

Inputs:
Language: {language}
Summary: {summary}
Architecture overview: {architecture_overview}
Requirements summary: {requirements_summary}

Produce JSON for the structural layout of the project files needed to implement the described project:
{{
  "files": [
     {{"filename": "{{base filename.ext without path}}", "directory": "ROOT or ROOT-respective-path", "purpose": "...", "functions": ["func1", "func2"]}},
  ]
}}

Rules:
- You must include dockerfile, docker-compose.yaml, readme.md, and dependency manifest at the bottom of the filelist.
- Prefer fewer files than more.
- `purpose` must indicate the role of the file in the project: it MUST also describe key functions/classes literally defined in the file so that later code generation can take those into account.
- Do NOT excessively chunk or break files into separate units.
- Do NOT include unnecessary services (like postgres db) in docker-compose unless specified or required.
- README must describe project for internal engineering. Short and concise. No license info. No contribution guidelines. No marketing content. No contact info. Just do NOT mention them.

Return ONLY valid JSON.
"""

CODE_PROMPT = """
You are an expert {language} engineer. You are to author a single file as part of a larger project that is described below.

Purpose: {purpose}
---

Project summary: {summary}
---

Architecture overview:
{architecture_overview}
---

Requirements summary:
{requirements_summary}
---

Previous file summaries:
{previous_summaries}
---

Full file list:
{all_files}
---

Rules:
- Output ONLY the file contents for `{directory}/{filename}`.
- ABSOLUTELY complete and correct code. Do NOT leave any TODOs or placeholders for user fillin.
- Implement the code for completeness and correctness. Check that imports and dependencies are complete, accurate, and valid.
- Code must align with purpose. No extraneous code. No triple backticks. No unnecessary explanations or imports.
- Dockerfile must be runnable. docker-compose.yaml must reference Dockerfile and be minimal. No unnecessary services necessary in composition.
- Dependency manifest MUST be valid.
- Take all functions from prior files into account before authoring the dependency manifest.
- Concise README: No license info. No contribution guidelines. No marketing content. No contact info MUST be included here. Just describe project for internal engineering.

Generate full code for `{directory}/{filename}` (DO NOT return partial code or leave ellipsis/placeholders):

Code: 
"""

FILE_SUMMARY_PROMPT = """
Provide a concise 1–3 sentence summary describing what the provided file content accomplishes, along with key functions/classes defined in the file.

Return JSON:
{{
  "summary": "<1–3 sentence description>"
}}

File content:
---
{file_content}
---

Functions:
---
{functions}
---
"""


# =====================================================================
# PIPELINE EXECUTION
# =====================================================================
def generate_project_plan(description: str) -> ProjectPlan:
    msg = ChatMessage(role=MessageRole.USER,
        blocks=[TextBlock(text=PLAN_PROMPT.format(description=description))])
    return plan_llm.chat([msg]).raw


def generate_file_layout(plan: ProjectPlan) -> FileLayout:
    msg = ChatMessage(role=MessageRole.USER,
        blocks=[TextBlock(text=LAYOUT_PROMPT.format(
            language=plan.language,
            summary=plan.summary,
            architecture_overview=plan.architecture_overview,
            requirements_summary=plan.requirements_summary
        ))])
    return layout_llm.chat([msg]).raw


def generate_file_summary(file_content: str, functions: list[str]) -> str:
    msg = ChatMessage(role=MessageRole.USER,
        blocks=[TextBlock(text=FILE_SUMMARY_PROMPT.format(file_content=file_content, functions=", ".join(functions) if functions else ""))])
    summary_obj = summary_llm.chat([msg]).raw
    return summary_obj.summary.strip()


def generate_code(plan: ProjectPlan, layout: FileLayout, file: FileSpec, previous_summaries: str) -> str:
    msg = ChatMessage(role=MessageRole.USER,
        blocks=[TextBlock(text=CODE_PROMPT.format(
            language=plan.language,
            filename=file.filename,
            directory=file.directory,
            purpose=file.purpose,
            summary=plan.summary,
            architecture_overview=plan.architecture_overview,
            requirements_summary=plan.requirements_summary,
            previous_summaries=previous_summaries or "None.",
            all_files=json.dumps([f.dict() for f in layout.files], indent=2)
        ))])
    resp = llm.chat([msg])
    return resp.message.content.strip()


# =====================================================================
# WRITE FILES + ZIP
# =====================================================================
def write_files_to_disk(project_id: str, layout: FileLayout, file_code_map: dict):
    base = Path(f"/tmp/project_{project_id}")
    if base.exists():
        shutil.rmtree(base)
    base.mkdir(parents=True, exist_ok=True)

    for file in layout.files:
        folder = base / file.directory.lstrip("ROOT/") if file.directory != "ROOT" else base
        folder.mkdir(parents=True, exist_ok=True)
        filename_only = os.path.basename(file.filename)
        filepath = folder / filename_only
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(file_code_map[file.filename])

    zip_path = f"/tmp/project_{project_id}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for root, dirs, files in os.walk(base):
            for file in files:
                full_path = os.path.join(root, file)
                arcname = os.path.relpath(full_path, base)
                archive.write(full_path, arcname)

    return zip_path


# =====================================================================
# STREAMLIT UI
# =====================================================================
def show():
    st.title("Coding Assistant")

    default_description = st.session_state.get(
        "preset_description",
        "Simple Hello World web application using Flask in Python."
    )

    description = st.text_area(
        "Describe your project:",
        value=default_description,
        height=150
    )
    st.session_state.preset_description = description

    if st.button("Author Project"):
        with st.spinner("Generating project plan..."):
            plan = generate_project_plan(description)

        st.caption("### Project Plan")
        for (k,v) in json.loads(plan.json()).items():
            st.caption(f"**{k.replace('_', ' ').title()}**: {v}")

        with st.spinner("Generating file layout..."):
            layout = generate_file_layout(plan)

        st.caption("### File Layout")
        df = pd.DataFrame([f.dict() for f in layout.files])
        st.dataframe(df, use_container_width=True)

        st.markdown("---")
        st.caption("### Generating Code")

        project_id = uuid.uuid4().hex
        file_code_map = {}
        file_summary_map = {}

        all_summaries = ""

        for file_spec in layout.files:
            with st.expander(f"{file_spec.directory}/{file_spec.filename} — {file_spec.purpose}"):

                with st.spinner("Generating code..."):
                    code_content = generate_code(plan, layout, file_spec, all_summaries)

                    # add to maps
                    file_code_map[file_spec.filename] = code_content

                    # summarize
                    summary_text = generate_file_summary(code_content, file_spec.functions)
                    
                    file_summary_map[file_spec.filename] = summary_text

                    # append for next file
                    all_summaries += f"- {file_spec.filename}: {summary_text}\n"

                st.info(summary_text)
                st.caption(file_spec.functions if file_spec.functions else "")
                st.code(code_content, language=plan.language.lower())

        if file_code_map:
            zip_path = write_files_to_disk(project_id, layout, file_code_map)
            with open(zip_path, "rb") as f:
                fname = plan.archive_zip_filename or f"project_{project_id}.zip"
                st.download_button(
                    "Download Project ZIP",
                    f,
                    file_name=fname,
                    mime="application/zip"
                )


if __name__ == "__main__":
    show()
