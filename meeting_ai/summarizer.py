import os
from typing import Any, List, Optional

import pandas as pd
from pydantic import BaseModel, Field

from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate

from llama_index.core import Document
from llama_index.core.node_parser import SimpleNodeParser

# ---------------------------------------------------------------------------
# LLM + Cache
# ---------------------------------------------------------------------------

MODEL_NAME = os.getenv("MODEL_NAME", "qwen2.5vl:7b")
BASE_URL = os.getenv("BASE_URL", "http://localhost:11434")


def get_llm(
    model_name: str = MODEL_NAME,
    base_url: str = BASE_URL,
    temperature: float = 0.01,
    timeout: int = 240,
) -> ChatOllama:
    """
    Modern LangChain ChatOllama wrapper.
    """
    return ChatOllama(
        model=model_name,
        base_url=base_url,
        temperature=temperature,
        request_timeout=timeout,
        context_window=4096,
    )


def llm_decorator():
    """
    Injects an LLM as the first argument of the wrapped function.
    """
    import functools

    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            llm = get_llm(
                model_name=kwargs.get("model_name", MODEL_NAME),
                base_url=kwargs.get("base_url", BASE_URL),
                temperature=kwargs.get("temperature", 0.01),
                timeout=kwargs.get("timeout", 240),
            )
            args = (llm,) + args
            try:
                return func(*args, **kwargs)
            finally:
                del llm

        return wrapper

    return decorator


# ---------------------------------------------------------------------------
# Pydantic models for structured outputs
# ---------------------------------------------------------------------------


class SegmentSummary(BaseModel):
    """Structured summary for one transcript chunk."""
    segment_index: int
    start_time: float
    end_time: float
    speakers: List[str]
    summary: str


class MeetingSummary(BaseModel):
    """High-level structured summary of the full meeting."""
    overall_summary: str
    topics: List[str] = Field(default_factory=list)
    decisions: List[str] = Field(default_factory=list)
    action_items: List[str] = Field(default_factory=list)
    risks: List[str] = Field(default_factory=list)
    follow_ups: List[str] = Field(default_factory=list)

    # NEW: LLM-inferred identities
    speaker_identities: dict = Field(
        default_factory=dict,
        description="Mapping of diarized labels (speaker0) → inferred human names/roles."
    )


# ---------------------------------------------------------------------------
# Transcript → LlamaIndex Documents
# ---------------------------------------------------------------------------


def generate_transcript_docs(transcription_df: pd.DataFrame) -> List[Document]:
    """
    Build LlamaIndex Documents from diarized Whisper DataFrame.
    """
    df = transcription_df.copy()

    df["Start Time"] = df["Start Time"].astype(float)
    df.sort_values(by=["Start Time"], inplace=True)
    df.dropna(subset=["Whisper Transcription"], inplace=True)

    docs = []
    for _, row in df.iterrows():
        speaker = str(row["Speaker"]).strip()
        text = str(row["Whisper Transcription"])

        # Provide raw "speaker0", "speaker1" to the summary LLM
        page_content = f"{speaker}: {text}"

        docs.append(
            Document(
                text=page_content,
                metadata={
                    "start": float(row["Start Time"]),
                    "end": float(row["End Time"]),
                    "speaker": speaker,
                    "raw_text": text,
                },
            )
        )

    return docs


# ---------------------------------------------------------------------------
# Prompts (Segment + Final Summary)
# ---------------------------------------------------------------------------


segment_prompt = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            "You summarize small transcript segments concisely and clearly."
        ),
        (
            "human",
            "Segment index: {segment_index}\n"
            "Time range: {time_range}\n"
            "Speakers: {speakers}\n\n"
            "Transcript:\n{segment_text}\n\n"
            "Write a concise summary."
        ),
    ]
)

# -- FINAL PROMPT: Now infers real human-like speaker identities --
final_prompt = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            "You produce expert structured meeting summaries.\n"
            "The transcript contains diarized speaker labels such as 'speaker0', 'speaker1'.\n"
            "Infer realistic names or professional roles for each speaker.\n"
            "If uncertain, choose the most likely professional role.\n"
            "Always produce a mapping for *every speaker label observed*."
        ),
        (
            "human",
            "You are given multiple segment summaries.\n\n"
            "Segment Summaries:\n{segment_summaries}\n\n"
            "TASKS:\n"
            "1. Infer human-like speaker identities.\n"
            "2. Produce a structured summary with:\n"
            "- overall_summary\n"
            "- topics\n"
            "- decisions\n"
            "- action_items\n"
            "- risks\n"
            "- follow_ups\n"
            "- speaker_identities (dictionary: speakerX → inferred name/role)\n\n"
            "Return ONLY data that fits the Pydantic schema exactly."
        ),
    ]
)


# ---------------------------------------------------------------------------
# Async workers
# ---------------------------------------------------------------------------


async def _summarize_segments_async(
    llm: ChatOllama,
    docs: List[Document],
    progress_status: Optional[Any] = None,
) -> List[SegmentSummary]:

    parser = SimpleNodeParser.from_defaults(chunk_size=1200, chunk_overlap=50)
    nodes = parser.get_nodes_from_documents(docs)

    structured_llm = llm.with_structured_output(SegmentSummary)
    chain = segment_prompt | structured_llm

    collapsed = []
    total = max(len(nodes), 1)
    sub_progress = progress_status.progress(0) if progress_status else None

    for idx, node in enumerate(nodes):
        md = node.metadata or {}
        start = float(md.get("start", 0.0))
        end = float(md.get("end", 0.0))
        speaker = md.get("speaker", "unknown")

        speakers = [speaker]

        if sub_progress:
            sub_progress.progress(
                (idx + 1) / total,
                text=node.text[:140] + ("..." if len(node.text) > 140 else "")
            )

        seg: SegmentSummary = await chain.ainvoke(
            {
                "segment_index": idx,
                "time_range": f"{start:.2f}s to {end:.2f}s",
                "speakers": ", ".join(speakers),
                "segment_text": node.text,
            }
        )

        seg.segment_index = idx
        seg.start_time = start
        seg.end_time = end
        seg.speakers = speakers

        collapsed.append(seg)

    return collapsed


async def _generate_final_summary_async(
    llm: ChatOllama,
    segment_summaries: List[SegmentSummary],
    progress_status: Optional[Any] = None,
) -> MeetingSummary:

    structured_llm = llm.with_structured_output(MeetingSummary)
    chain = final_prompt | structured_llm

    if progress_status:
        progress_status.write(f"Combining {len(segment_summaries)} segment summaries...")
        progress_status.update(label="Collapsing summaries...", state="running")

    bullet_lines = "\n".join(
        f"- [{s.start_time:.1f}s–{s.end_time:.1f}s] {s.summary}"
        for s in segment_summaries
    )

    final_summary: MeetingSummary = await chain.ainvoke(
        {
            "segment_summaries": bullet_lines,
        }
    )

    if progress_status:
        progress_status.update(label="Final summary done.", state="complete")

    return final_summary


# ---------------------------------------------------------------------------
# Public entry point — generate_summary()
# ---------------------------------------------------------------------------


@llm_decorator()
def generate_summary(
    llm: ChatOllama,
    transcription_df: pd.DataFrame,
    progress_status: Optional[Any] = None,
    **kwargs,
):
    """
    PUBLIC ENTRY POINT
    Drop-in replacement for your original generate_summary()

    Returns:
    {
        "collapsed_summaries": List[SegmentSummary],
        "final_summary": MeetingSummary
    }
    """
    import asyncio

    async def _run():
        docs = generate_transcript_docs(transcription_df)

        if progress_status:
            progress_status.write("Generating segment-level summaries...")

        collapsed = await _summarize_segments_async(llm, docs, progress_status)

        if progress_status:
            progress_status.write("Generating structured final summary...")

        final_summary = await _generate_final_summary_async(llm, collapsed, progress_status)

        return collapsed, final_summary

    try:
        collapsed, summary = asyncio.run(_run())
    except RuntimeError:
        loop = asyncio.new_event_loop()
        try:
            collapsed, summary = loop.run_until_complete(_run())
        finally:
            loop.close()

    return {
        "collapsed_summaries": collapsed,
        "final_summary": summary,
    }
